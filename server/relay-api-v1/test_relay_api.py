"""Offline contract tests matching iOS JSONEncoder millisecondsSince1970."""
import base64
import json
import os
import tempfile
import unittest

from relay_api import RelayStore, MAX_FRAME_BYTES

R="A"*43
W="B"*43
M="C"*32
P="a0288e2e-88d5-439f-8a0f-24663bc10ee8"

class RelayContractTest(unittest.TestCase):
    def setUp(self):
        self.now=1_780_000_000_000
        self.s=RelayStore(clock=lambda: self.now)
        self.addCleanup(self.s.close)

    def post(self,path,body):
        return self.s.request('POST',path,headers={'Content-Type':'application/json'},body=json.dumps(body).encode())

    def register(self, mailbox=M, read=R,write=W):
        return self.post('/v1/register', dict(version=1,mailbox=mailbox,readToken=read,writeToken=write,expiresAt=self.now+180000))

    def push(self, mailbox=M, write=W, packet=P, payload=b'ciphertext'):
        return self.post('/v1/push',dict(version=1,mailbox=mailbox,writeToken=write,packetID=packet,expiresAt=self.now+120000,body=base64.b64encode(payload).decode()))

    def pull(self, mailbox=M, read=R):
        return self.s.request('GET','/v1/pull',query='mailbox='+mailbox,headers={'Authorization':'Bearer '+read})

    def ack(self, ids=[P],read=R,mailbox=M):
        return self.post('/v1/ack', dict(version=1,mailbox=mailbox,readToken=read,packetIDs=ids))

    def test_health(self):
        self.assertEqual(self.s.request('GET','/v1/health'),(200,{'status':'ok','version':1}))

    def test_register_send_pull_ack(self):
        self.assertEqual(self.register()[0],200)
        self.assertEqual(self.push()[0],200)
        status, response = self.pull()
        self.assertEqual(status,200)
        self.assertEqual(response['version'],1)
        self.assertEqual(len(response['packets']),1)
        self.assertEqual(base64.b64decode(response['packets'][0]['body']),b'ciphertext')
        self.assertEqual(response['packets'][0]['packetID'],P)
        self.assertEqual(self.ack()[0],200)
        self.assertEqual(self.pull()[1]['packets'],[])

    def test_unauthorized_token_read_write_and_registration_conflict(self):
        self.register()
        self.assertEqual(self.push(write='Q'*43)[0],403)
        self.assertEqual(self.pull(read='Q'*43)[0],403)
        self.assertEqual(self.ack(read='Q'*43)[0],403)
        self.assertEqual(self.register(read='Q'*43)[0],409)
        self.assertEqual(self.register()[0],200)

    def test_expired_mailbox_and_packet_do_not_reappear(self):
        self.register()
        self.push()
        self.now+=120001
        self.assertEqual(self.pull()[1]['packets'],[])
        self.now+=60000
        self.assertEqual(self.pull()[0],403)

    def test_duplicate_packet_idempotent_and_conflicting(self):
        self.register()
        self.assertEqual(self.push()[0],200)
        self.assertEqual(self.push()[1].get('duplicate'),True)
        self.assertEqual(self.push(payload=b'changed')[0],409)
        self.assertEqual(len(self.pull()[1]['packets']),1)

    def test_full_envelope_and_oversize_rejection(self):
        self.register()
        self.assertEqual(self.push(payload=b'Z'*MAX_FRAME_BYTES)[0],200)
        self.assertEqual(self.push(packet='a'*36,payload=b'Z'*(MAX_FRAME_BYTES+1))[0],413)

    def test_malformed_data_is_rejected_without_persistent_side_effect(self):
        self.assertEqual(self.post('/v1/register',dict(version=True,mailbox=M,readToken=R,writeToken=W,expiresAt=self.now+120000))[0],400)
        self.assertEqual(self.post('/v1/register',dict(version=1,mailbox=M,readToken=R,writeToken=W,expiresAt='bad'))[0],400)
        self.assertEqual(self.pull()[0],403)
        self.assertEqual(self.s.request('POST','/v1/register',headers={'Content-Type':'application/json'},body=b'not json')[0],400)
        self.assertEqual(self.post('/v1/register',dict(version=1,mailbox=M,readToken=R,writeToken=R,expiresAt=self.now+120000))[0],400)
        self.assertEqual(self.register()[0],200)

    def test_two_providers_distinct_mailboxes_and_secret_isolation(self):
        second=RelayStore(clock=lambda:self.now)
        self.addCleanup(second.close)
        self.register()
        self.push()
        self.assertEqual(second.request('GET','/v1/pull',query='mailbox='+M,headers={'Authorization':'Bearer '+R})[0],403)

    def test_sqlite_cold_restart_preserves_unacked_ciphertext(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=os.path.join(tmp,'relay.sqlite3')
            a=RelayStore(path,clock=lambda:self.now)
            try:
                payload=dict(version=1,mailbox=M,readToken=R,writeToken=W,expiresAt=self.now+180000)
                self.assertEqual(a.request('POST','/v1/register',headers={'content-type':'application/json'},body=json.dumps(payload).encode())[0],200)
                packet=dict(version=1,mailbox=M,writeToken=W,packetID=P,expiresAt=self.now+120000,body=base64.b64encode(b'encrypted').decode())
                self.assertEqual(a.request('POST','/v1/push',headers={'content-type':'application/json'},body=json.dumps(packet).encode())[0],200)
            finally: a.close()
            b=RelayStore(path,clock=lambda:self.now)
            try:
                result=b.request('GET','/v1/pull',query='mailbox='+M,headers={'authorization':'Bearer '+R})
                self.assertEqual(result[0],200)
                self.assertEqual(len(result[1]['packets']),1)
            finally: b.close()

    def test_ack_replay_is_idempotent_without_redelivery(self):
        self.register()
        self.assertEqual(self.push()[0], 200)
        self.assertEqual(self.ack()[0], 200)
        self.assertEqual(self.pull()[1]["packets"], [])
        status, duplicate = self.push()
        self.assertEqual(status, 200)
        self.assertTrue(duplicate.get("duplicate"))
        self.assertEqual(self.pull()[1]["packets"], [])
        self.assertEqual(self.push(payload=b"changed")[0], 409)

    def test_ack_replay_receipt_survives_restart(self):
        with tempfile.TemporaryDirectory() as root:
            path = os.path.join(root, "relay.sqlite3")
            def post(store, path, body):
                return store.request("POST", path, headers={"content-type": "application/json"},
                                     body=json.dumps(body).encode("utf8"))
            registration = dict(version=1, mailbox=M, readToken=R, writeToken=W,
                                expiresAt=self.now+180000)
            packet = dict(version=1, mailbox=M, writeToken=W, packetID=P,
                          expiresAt=self.now+120000,
                          body=base64.b64encode(b"encrypted").decode())
            ack = dict(version=1, mailbox=M, readToken=R, packetIDs=[P])
            one = RelayStore(path, clock=lambda:self.now)
            try:
                self.assertEqual(post(one, "/v1/register", registration)[0], 200)
                self.assertEqual(post(one, "/v1/push", packet)[0], 200)
                self.assertEqual(post(one, "/v1/ack", ack)[0], 200)
            finally:
                one.close()
            two = RelayStore(path, clock=lambda:self.now)
            try:
                result = post(two, "/v1/push", packet)
                self.assertEqual(result[0], 200)
                self.assertTrue(result[1].get("duplicate"))
                pulled = two.request("GET", "/v1/pull", query="mailbox="+M,
                                     headers={"authorization":"Bearer "+R})
                self.assertEqual(pulled[1]["packets"], [])
                self.assertEqual(post(two, "/v1/push", dict(packet,
                    body=base64.b64encode(b"other").decode()))[0], 409)
            finally:
                two.close()

    def test_method_and_path_hardening(self):
        self.assertEqual(self.s.request('GET','/v1/unknown')[0],404)
        self.assertEqual(self.s.request('GET','/v1/register')[0],405)
        self.assertEqual(self.s.request('POST','/v1/ack',body=b'{}')[0],415)

if __name__ == '__main__':
    unittest.main()