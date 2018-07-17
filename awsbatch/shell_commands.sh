#!/bin/bash
set -e
cd "$(dirname "$0")"


pip install awscli==1.15.35 
clear 

create_env(){
	compute_env_name="$(jq '.computeEnvironmentName' computeEnv.json | sed -e 's/^"//' -e 's/"$//')"
	echo "Creating Compute Environment $compute_env_name"
	file_path="$(realpath computeEnv.json)"
	cmd="aws batch create-compute-environment --cli-input-json file://$file_path > compute_env_creation_op.json"
	echo $cmd
	eval "${cmd}"
}


delete_env(){
	compute_env_name="$(jq '.computeEnvironmentName' compute_env_creation_op.json | sed -e 's/^"//' -e 's/"$//')"
	echo "Disabling  Compute Environment $compute_env_name"
	disable_command="aws batch update-compute-environment --compute-environment $compute_env_name --state DISABLED"
	eval "${disable_command}"
	sleep 30s
	delete_comamnd="aws batch delete-compute-environment --compute-environment $compute_env_name"
	eval "${delete_comamnd}"
}


create_job_queue(){
	job_queue_name="$(jq '.jobQueueName' job_queue.json | sed -e 's/^"//' -e 's/"$//')"
	file_path="$(realpath job_queue.json)"
	echo "Creating job queue $job_queue_name"
	cmd="aws batch create-job-queue --cli-input-json file://$file_path > create_job_queue_op.json"
	echo $cmd
	eval "${cmd}"
}

await_queue_deletion(){
	queue_name=$1
	echo "Getting status for $queue_name"
	exit=false
	while [ "$exit" != true ]
	do
		eval $(aws batch describe-job-queues --job-queues $queue_name > _q_status.json)
		total=$(jq '.jobQueues| length' _q_status.json)
		if [[ $total > 0 ]]; then
		  available_queues=$(jq '.jobQueues[] | { name: .jobQueueName? }' _q_status.json)
		  
		  if [[ $available_queues = *$queue_name* ]]; then
		  		exit=false
		  fi
		  
		  else
				exit=true
		fi
   		echo "Found $total queues"
	done
	rm -rf _q_status.json
}


delete_job_queue(){
	job_queue_name="$(jq '.jobQueueName' create_job_queue_op.json | sed -e 's/^"//' -e 's/"$//')"
	echo "Deleting job queue $job_queue_name"
	disable_command="aws batch update-job-queue --job-queue $job_queue_name --state DISABLED"
	echo $disable_command
	eval "${disable_command]}"
	sleep 30s
	delete_comamnd="aws batch delete-job-queue --job-queue $job_queue_name"
	echo $delete_comamnd
	eval "${delete_comamnd]}"
	await_queue_deletion $job_queue_name
}


# jq '.jobQueues[] | { name: .jobQueueName? }' test_jq.json

create_env
sleep 3m
create_job_queue
sleep 3m 

delete_job_queue
sleep 30s 
delete_env


