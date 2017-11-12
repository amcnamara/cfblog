function configure() {
    TITLE=$(echo $@)
    NOW=$(date +"%m%d%Y%H%M")

    mkdir $NOW.${TITLE/\ /_}
    cd $_

    touch abstract.txt
    touch content.md
    touch publish.lock
}