#!/bin/bash
# This script detects zombie processes that are descendants of containerd-shim processes
# and first attempts to prompt the parent process to reap them by sending a SIGCHLD signal.

find_zombie_and_parents() {
  for pid in /proc/[0-9]*; do
    if [[ -r $pid/stat ]]; then
      read -r proc_pid comm state ppid < <(cut -d' ' -f1,2,3,4 "$pid/stat")
      if [[ $state == "Z" ]]; then
        echo "$proc_pid $ppid"
        return 0
      fi
    fi
  done
  return 1
}

get_parent_chain() {
  local pid=$1
  local chain=""
  while [[ $pid -ne 1 ]]; do
    if [[ ! -r /proc/$pid/stat ]]; then
      break
    fi
    read -r ppid cmd < <(awk '{print $4, $2}' /proc/$pid/stat)
    chain="$pid:$cmd $chain"
    pid=$ppid
  done
  echo "$chain"
}

is_process_zombie() {
  local pid=$1
  if [[ -r /proc/$pid/stat ]]; then
    read -r state < <(cut -d' ' -f3 /proc/$pid/stat)
    [[ $state == "Z" ]]
  else
    return 1
  fi
}

attempt_kill() {
  local pid=$1
  local signal=$2
  local wait_time=$3
  local signal_name=${4:-$signal}

  echo "Attempting to send $signal_name to parent process $pid"
  kill $signal $pid
  sleep $wait_time

  if is_process_zombie $zombie_pid; then
    echo "Zombie process $zombie_pid still exists after $signal_name"
    return 1
  else
    echo "Zombie process $zombie_pid no longer exists after $signal_name"
    return 0
  fi
}

if zombie_info=$(find_zombie_and_parents); then
  zombie_pid=$(echo "$zombie_info" | awk '{print $1}')
  parent_pid=$(echo "$zombie_info" | awk '{print $2}')

  echo "Found zombie process $zombie_pid with immediate parent $parent_pid"

  parent_chain=$(get_parent_chain "$parent_pid")
  echo "Parent chain: $parent_chain"

  if [[ $parent_chain == *"containerd-shim"* ]]; then
    echo "Top-level parent is containerd-shim"
    immediate_parent=$(echo "$parent_chain" | awk -F' ' '{print $1}' | cut -d':' -f1)
    if [[ $immediate_parent != $parent_pid ]]; then
      if attempt_kill $parent_pid -SIGCHLD 15 "SIGCHLD"; then
        echo "Zombie process cleaned up after SIGCHLD"
      elif attempt_kill $parent_pid -SIGTERM 15 "SIGTERM"; then
        echo "Zombie process cleaned up after SIGTERM"
      elif attempt_kill $parent_pid -SIGKILL 5 "SIGKILL"; then
        echo "Zombie process cleaned up after SIGKILL"
      else
        echo "Failed to clean up zombie process after all attempts"
      fi
    else
      echo "Immediate parent is containerd-shim. Not killing."
    fi
  else
    echo "Top-level parent is not containerd-shim. No action taken."
  fi
fi
