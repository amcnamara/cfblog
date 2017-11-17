VERSION="1.0"
function touch_version() {
    echo "version=$VERSION" > .gitblog
}

function cd_base() {
    while [ ! -e "./.gitblog" ]; do
	if [ $PWD == "/" ]; then
            echo "You are not in a git-blog directory"
            exit 1
	else
            cd ..
	fi
    done

    # Any command which operates at the base of the repo should mark the binary version
    touch_version
}

function is_config_attribute() {
    cd_base

    # NOTE: This craps out when inlined(?).
    regex="$1:[[:blank:]]*([[:alnum:]]+)"

    if [[ $(cat ./config.yaml) =~ $regex ]]; then
	if [[ "true" == $(echo ${BASH_REMATCH[1]} | tr '[:upper:]' '[:lower:]') ]]; then
	    return 0
	fi
    fi

    return 1
}

function usage() {
    cat <<EOF
Usage:
  git-blog --help            This message
  git-blog init <name>       Creates a new local blog repo, with some default assets
  git-blog clone <target>    Creates a local copy of an existing published blog
  git-blog configure         Configures global metadata (social handles, AWS credentials, etc) on an existing blog repo
  git-blog add <title>       Creates a new blog post
  git-blog build             Builds all static assets into public
  git-blog publish           Copies static assets to target S3 bucket
EOF
}
