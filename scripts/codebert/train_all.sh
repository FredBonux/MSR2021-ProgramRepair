#!/bin/bash

# Load .env variables
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "ERROR: .env does not exist."
    exit
fi

sizes=(small large)
types=(repetition unique)

lr=5e-5
batch_size=8
beam_size=5
source_length=510
target_length=510
train_steps=50000
eval_steps=1000
# size=small  # Can be: small OR large
# type=unique  # Can be: repetition OR unique
pretrained_model=./codebert-base  # CodeBert model path downloaded from Huggingface
CodeBERT=./codebert

for size in "${sizes[@]}"
do
    for type in "${types[@]}"
    do
        # I've already completed small-unique experiment so no need to repeat it
        if [ "$size" != "small" ] || [ "${type}" != "unique" ]; then 
            echo "Starting training for ($size - $type)"

            data_dir=./data/$type/split/$size
            output_dir=./saved_models/codebert/$type/$size
            train_file=$data_dir/src-train.txt,$data_dir/tgt-train.txt
            validate_file=$data_dir/src-val.txt,$data_dir/tgt-val.txt

            python $CodeBERT/run.py \
--do_train \
--do_eval \
--model_type roberta \
--model_name_or_path $pretrained_model \
--tokenizer_name roberta-base \
--train_filename $train_file \
--dev_filename $validate_file \
--output_dir $output_dir \
--max_source_length $source_length \
--max_target_length $target_length \
--beam_size $beam_size \
--train_batch_size $batch_size \
--eval_batch_size $batch_size \
--learning_rate $lr \
--train_steps $train_steps \
--eval_steps $eval_steps

            echo "Completed training for ($size - $type)" 


            # LogSnag push notification
            curl -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer $LOGSNAG_API_KEY"\
            -d "{\"project\": \"research\",\"event\": \"Training step complete\",\"description\": \"$size - $type\",\"icon\": \"⌛\",\"notify\": true,\"channel\": \"codebert-experiment\"}"\
            https://api.logsnag.com/v1/log

            echo "Starting testing for ($size - $type)"

            data_dir=./data/$type/split/$size
            output_dir=./saved_models/codebert/$type/$size
            train_file=$data_dir/src-train.txt,$data_dir/tgt-train.txt
            validate_file=$data_dir/src-val.txt,$data_dir/tgt-val.txt

            batch_size=8
            beam_size=5
            source_length=510
            target_length=510
            test_file=$data_dir/src-test.txt,$data_dir/tgt-test.txt
            test_model=$output_dir/checkpoint-best-ppl/pytorch_model.bin
            pretrained_model=./codebert-base
            CodeBERT=./codebert

            python $CodeBERT/run.py \
--do_test \
--model_type roberta \
--model_name_or_path $pretrained_model \
--tokenizer_name roberta-base  \
--load_model_path $test_model \
--dev_filename $validate_file \
--test_filename $test_file \
--output_dir $output_dir \
--max_source_length $source_length \
--max_target_length $target_length \
--beam_size $beam_size \
--eval_batch_size $batch_size

            echo "Completed testing for ($size - $type)"

            # LogSnag push notification
            curl -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer $LOGSNAG_API_KEY"\
            -d "{\"project\": \"research\",\"event\": \"Testing step complete\",\"description\": \"$size - $type\",\"icon\": \"⌛\",\"notify\": true,\"channel\": \"codebert-experiment\"}"\
            https://api.logsnag.com/v1/log

        fi
    done
done


# LogSnag push notification that testing is completed
curl -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer $LOGSNAG_API_KEY" -d '{"project": "research","event": "Experiments completed","description": "Experiments are done!","icon": "✅","notify": true,"channel": "codebert-experiment"}' https://api.logsnag.com/v1/log