#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
	if [[ ${GIT_AUTO_SYNC_DEBUG:-} == 'true' ]]; then
		set -o xtrace
	fi

	if [[ $1 == 'install' ]]; then
		install "${@:2}"
		exit
	fi

	# Intentionally global
	last_reflog_entry="$(git reflog show --max-count 1)"
	pull_rebase_regex='^.*: (pull|rebase)( .*)?: .+'
	last_commit="$(get_last_commit)"
	hook_name="$1"

	local -a sync_command=("${@:3:$2}")
	local -a hook_args=("${@:$(($2 + 3))}")

	# We'll consider the repository synced with any commit made locally.
	if
		# post-commit hooks triggered during a pull/rebase shouldn't count
		[[ $hook_name == 'post-commit' && ! $last_reflog_entry =~ $pull_rebase_regex ]] ||
				[[ $hook_name == 'post-rewrite' && ${hook_args[0]} == 'amend' ]]
	then
		track_last_synced_commit
		exit
	fi

	should_sync="$(should_sync "${hook_args[@]}")"
	if [[ $should_sync == 'true' ]]; then
		# Even if the sync doesn't succeed, we still want to consider the repository
		# synced against the current commit since the user will probably fix whatever
		# wasn't working and rerun the sync.
		trap track_last_synced_commit EXIT
		echo '[git-auto-sync] Syncing...' >&2
		GIT_AUTO_SYNC_LAST_COMMIT="$last_commit" "${sync_command[@]}"
	fi
}

function install {
	for hook in post-checkout post-merge post-rewrite post-commit; do
		git config "hook.auto-sync-$hook.event" "$hook"
		git config "hook.auto-sync-$hook.command" "git-auto-sync $hook $# ${*@Q}"
	done
}

function track_last_synced_commit {
	local last_commit_path
	last_commit_path="$(get_last_commit_path)"
	git rev-parse 'HEAD' >"$last_commit_path"
}

function get_last_commit_path {
	local git_directory
	git_directory="$(git rev-parse --absolute-git-dir)"
	echo "$git_directory/git-auto-sync-last-commit"
}

function get_last_commit {
	local last_commit_path
	last_commit_path="$(get_last_commit_path)"
	if [[ -e $last_commit_path ]]; then
		echo "$(<"$last_commit_path")"
	fi
}

function should_sync {
	local should_sync='true'

	if
		[[ ${GIT_AUTO_SYNC_SKIP:-} == 'true' ]] ||
			# There are no differences between the last synced commit and the current one.
			{ [[ -n $last_commit ]] && git diff-tree --exit-code --quiet "$last_commit" 'HEAD'; }
	then
		should_sync='false'
	fi

	case "${hook_name:?}" in
		'post-merge' | 'post-rewrite')
			;;
		'post-commit')
			should_sync='false'
			;;
		'post-checkout')
			if
				# This is a file checkout.
				(($3 == 0)) ||
					# We're in the middle of a pull/rebase. We shouldn't sync here since
					# post-merge/post-rewrite will run when the pull/rebase is finished.
					[[ $last_reflog_entry =~ $pull_rebase_regex ]] ||
					# The destination commit has been pushed to the default branch. Here, I
					# assume the user is going through the history to debug. As such, we
					# shouldn't sync.
					git merge-base --is-ancestor "$2" origin
			then
				should_sync='false'
			fi
			;;
		*)
			echo "git-auto-sync: Error, invalid hook name: $hook_name" >&2
			exit 1
			;;
	esac

	echo "$should_sync"
}

main "$@"
