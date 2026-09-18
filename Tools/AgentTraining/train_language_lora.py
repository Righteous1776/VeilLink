#!/usr/bin/env python3
"""GPU-oriented LoRA/QLoRA carrier for VeilLink's future local language runtime.

This script intentionally does not download or commit a model during normal repository CI.
Run it on a connected GPU host after model/dataset license and SHA provenance are pinned.
"""
import argparse, hashlib, json, os
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--base-model',default='Qwen/Qwen2.5-0.5B-Instruct')
    ap.add_argument('--revision',default='c89bee90d9f811437d9735454613c35b4a3c4dc8')
    ap.add_argument('--weight-filename',default='model.safetensors')
    ap.add_argument('--expected-weight-sha256',default='fdf756fa7fcbe7404d5c60e26bff1a0c8b8aa1f72ced49e7dd0210fe288fb7fe')
    ap.add_argument('--data',required=True,help='JSONL with {messages:[{role,content},...]}')
    ap.add_argument('--out',required=True)
    ap.add_argument('--epochs',type=float,default=2.0)
    ap.add_argument('--lr',type=float,default=2e-4)
    ap.add_argument('--max-length',type=int,default=512)
    ap.add_argument('--lora-r',type=int,default=16)
    args=ap.parse_args()
    try:
        import torch
        from datasets import load_dataset
        from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments, Trainer, DataCollatorForLanguageModeling
        from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
        from huggingface_hub import hf_hub_download
    except Exception as exc:
        raise SystemExit('Install GPU training extras: transformers datasets peft accelerate bitsandbytes. '+str(exc))
    if not torch.cuda.is_available():
        raise SystemExit('This carrier is intentionally GPU-only; do not pretend CPU smoke training is the final language-model run.')
    weight_path=hf_hub_download(repo_id=args.base_model,filename=args.weight_filename,revision=args.revision)
    digest=hashlib.sha256(Path(weight_path).read_bytes()).hexdigest()
    if digest.lower()!=args.expected_weight_sha256.lower():
        raise SystemExit(f'Pinned model hash mismatch: expected {args.expected_weight_sha256}, got {digest}')
    tokenizer=AutoTokenizer.from_pretrained(args.base_model,revision=args.revision,use_fast=True,trust_remote_code=False)
    model=AutoModelForCausalLM.from_pretrained(args.base_model,revision=args.revision,torch_dtype=torch.float16,device_map='auto',load_in_4bit=True,trust_remote_code=False)
    model=prepare_model_for_kbit_training(model)
    model.gradient_checkpointing_enable()
    config=LoraConfig(r=args.lora_r,lora_alpha=args.lora_r*2,lora_dropout=0.05,bias='none',task_type='CAUSAL_LM',target_modules=['q_proj','k_proj','v_proj','o_proj','gate_proj','up_proj','down_proj'])
    model=get_peft_model(model,config)
    ds=load_dataset('json',data_files={'train':args.data})['train']
    def tokenize(row):
        text=tokenizer.apply_chat_template(row['messages'],tokenize=False,add_generation_prompt=False)
        return tokenizer(text,truncation=True,max_length=args.max_length)
    ds=ds.map(tokenize,remove_columns=ds.column_names)
    ta=TrainingArguments(output_dir=args.out,num_train_epochs=args.epochs,learning_rate=args.lr,per_device_train_batch_size=2,gradient_accumulation_steps=16,logging_steps=10,save_strategy='epoch',fp16=True,report_to=[])
    trainer=Trainer(model=model,args=ta,train_dataset=ds,data_collator=DataCollatorForLanguageModeling(tokenizer,mlm=False))
    trainer.train(); model.save_pretrained(args.out); tokenizer.save_pretrained(args.out)
    Path(args.out,'TRAINING_MANIFEST.json').write_text(json.dumps({'base_model':args.base_model,'revision':args.revision,'weight_sha256':digest,'epochs':args.epochs,'lr':args.lr,'max_length':args.max_length,'lora_r':args.lora_r,'note':'requires separate model+dataset provenance and on-device benchmark before shipping'},indent=2),encoding='utf-8')
if __name__=='__main__': main()
