#!/usr/bin/env zsh

typeset -gaU path
[[ -d $HOME/bin ]] && path=($HOME/bin $path)
[[ -d $HOME/.local/bin ]] && path=($HOME/.local/bin $path)
# [[ -d $CUSTOM_AGENTS_DIR ]] && path=($CUSTOM_AGENTS_DIR $path)
# [[ -d $AGENT_PLUGINS_DIR ]] && path=($AGENT_PLUGINS_DIR $path)
export PATH

export SHELL_SESSIONS_DISABLE=1
export EDITOR=ttt
export VISUAL=nano
export AGENT=pi
# export AGENT_MODEL=gpt-6-astra
# export AGENT_EFFORT=high

export SKILLS_REPO=$HOME/repos/slurpyb/skills
if [[ -d $SKILLS_REPO ]]; then
    export AGENT_HOME=$SKILLS_REPO
else
    export SKILLS_HOME=$HOME/.agents
fi

# [[ -d $SKILLS_REPO ]] && export SKILLS_HOME=$SKILLS_REPO || export SKILLS_HOME=$HOME/.agents/skills
export AGENT_SKILLS_DIR=$AGENT_HOME/plugins/slurpyb/skills
export AGENT_PLUGINS_DIR=$AGENT_HOME/plugins
export AGENT_TASKS_DIR=$AGENT_HOME/tasks
export AGENT_DOCS_DIR=$HOME/.ai/docs
export AGENT_EXTENSIONS_DIR=$AGENT_HOME/extensions
export ACTIVE_AGENT_DIR="$HOME/.${AGENT}"
export ACTIVE_AGENT_SKILLS=$ACTIVE_AGENT_DIR/skills
export ACTIVE_AGENT_PROMPTS=$ACTIVE_AGENT_DIR/prompts
export ACTIVE_AGENT_RULES_FILE=$ACTIVE_AGENT_DIR/AGENTS.md
export ACTIVE_AGENT_APPEND_SYSTEM=$ACTIVE_AGENT_DIR/APPEND_SYSTEM.md
export ACTIVE_AGENT_SETTINGS=$ACTIVE_AGENT_DIR/settings.json
export ACTIVE_AGENT_MCP=$ACTIVE_AGENT_DIR/mcp.json
export PLUGINS=$AGENT_PLUGINS_DIR
# export KITTY_PASSWORD_MANAGER=1