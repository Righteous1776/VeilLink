"""Real loopback HTTP contract tests for VeilLink's existing iOS Relay client.

Test server is never exposed outside 127.0.0.1 and uses ephemeral port.
"""
import base64
import json
import threading
import time
import unittest
import urllib.error
import urllib.request

from http.server import ThreadingHTTPServer
from relay_api import Handler, RelayStore


class RealHTTPContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.store = RelayStore(":memory:")
        Handler.store = cls.store
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.address = "http://127.0.0.1:%d" % cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=3)
        cls.store.close()

    def request(self, path, method="GET", obj=None, bearer=None):
        headers = {}
        data = None
        if obj is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(obj).encode("utf8")
        if bearer:
            headers["Authorization"] = "Bearer " + bearer
        req = urllib.request.Request(self.address + path, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=3) as res:
                return res.status, json.load(res)
        except urllib.error.HTTPError as e:
            return e.code, json.load(e)

    def test_real_http_register_push_pull_ack(self):
        now = int(time.time() * 1000)
        mailbox = "C" * 32
        read, write = "A" * 43, "B" * 43
        packet = "bb92736c-87f1-4de6-890d-49b202fd4052"
        self.assertEqual(self.request("/v1/health"), (200, {"status":"ok","version":1}))
        registered = dict(version=1,mailbox=mailbox,readToken=read,writeToken=write,expiresAt=now+180_000)
        self.assertEqual(self.request("/v1/register", "POST", registered)[0],200)
        pushed = dict(version=1,mailbox=mailbox,packetID=packet,writeToken=write,expiresAt=now+120_000,
                      body=base64.b64encode(b"\x00\xffopaque-ciphertext").decode("ascii"))
        self.assertEqual(self.request("/v1/push","POST",pushed)[0],200)
        self.assertEqual(self.request("/v1/pull?mailbox="+mailbox,bearer="X"*43)[0],403)
        status, pulled = self.request("/v1/pull?mailbox="+mailbox,bearer=read)
        self.assertEqual(status,200)
        self.assertEqual(len(pulled["packets"]),1)
        self.assertEqual(base64.b64decode(pulled["packets"][0]["body"]),b"\x00\xffopaque-ciphertext")
        self.assertIsInstance(pulled["packets"][0]["receivedAt"],int)
        self.assertEqual(self.request("/v1/ack","POST",dict(version=1,mailbox=mailbox,readToken=read,packetIDs=[packet]))[0],200)
        self.assertEqual(self.request("/v1/pull?mailbox="+mailbox,bearer=read)[1]["packets"],[])
        repeat_status, repeat_result = self.request("/v1/push", "POST", pushed)
        self.assertEqual(repeat_status, 200)
        self.assertTrue(repeat_result.get("duplicate"))
        self.assertEqual(self.request("/v1/pull?mailbox="+mailbox,bearer=read)[1]["packets"],[])
        self.assertEqual(self.request("/v1/push","POST",dict(pushed,packetID="A"*36,writeToken="Q"*43))[0],403)

    def test_unsupported_method_and_bad_json_http(self):
        self.assertEqual(self.request("/v1/unknown")[0],404)
        self.assertEqual(self.request("/v1/register")[0],405)
        self.assertEqual(self.request("/v1/ack","POST",dict(version=False))[0],400)


if __name__ == "__main__":
    unittest.main()
