function build() {
    if [[ $PWD == $PUBLIC_DIR* ]]; then
        perror "Cannot run this script from within $PUBLIC_DIR, your current working directory will be removed"
        exit 1
    fi

    # Blow away all existing built assets, and copy in all static assets
    rm -rf $PUBLIC_DIR
    rsync -a $STATIC_DIR/* $PUBLIC_DIR

    # Find all markdown content (including siblings of the posts directory)
    content=$(find $CONTENT_DIR -name "*.md")

    if [[ ! ${content[@]} ]]; then
        echo "No content found to build, use \`${YELLOW}git-blog write <post_title>${NOCOLOUR}\` to create some!"
        exit 1
    fi

    # NOTE: Separately from \$content, which may include other documents,
    #       find all posts and order them alphabetically. Generated posts
    #       have their creation time prepended to the filename since the
    #       file metadata is lost during cloning. Chronological ordering
    #       here is particularly important for building the index, RSS, etc.
    posts=$(find $POST_DIR -name "*.md")
    posts=$(ls $posts)

    echo "Generating index of post metadata"

    # Generate a YAML list containing all post metadata. This will be plumbed
    # through all of the content templates, the index, and RSS feed.
    #
    # NOTE: String expression below is necessary to properly escape newlines.
    index=$'---\nindex:'

    for post in $posts; do
	index+="
  - title: $(multimarkdown -e=title $post)
    timestamp: $(multimarkdown -e=timestamp $post)
    datestamp: $(multimarkdown -e=datestamp $post)
    description: $(multimarkdown -e=description $post)"
    done

    index+=$'\n---'

    # Render all content
    for document in $content; do
        # Find the template and corresponding output path for the given document

        midpath=$(dirname $document)
        # NOTE: Trim off parent directories from content/ upward, and leading /
        midpath=${midpath:${#CONTENT_DIR}+1}

        template=$TEMPLATE_DIR/$midpath/template.mustache
        filename=$(basename $document | cut -d. -f1 -).html
        output=$PUBLIC_DIR/$midpath/$filename

        # Ensure that the template exists for the given document
        if [ ! -e $template ]; then
            pwarning "Cannot render document, skipping due to missing template:"
            echo "         document '$document'"
            echo "         expected template '$template'"
            continue
        fi

        # Ensure that public directory and midpath subdirectories exist
        if [ ! -e $PUBLIC_DIR/$midpath ]; then
            mkdir -p $PUBLIC_DIR/$midpath
        fi

        pbold "Writing $output"

        # TODO: Consider adding support for http://www.html-tidy.org/ on output
        cat <<METADATA | cat $CONFIG_FILE - | mustache - $template > $output
$index
---
$(for key in $(multimarkdown -m $document); do
  echo $key: $(multimarkdown -e=$key $document)
done)
content: '$(multimarkdown --snippet $document)'
---
METADATA
    done

    # Build options (all are recommended and enabled by default in new projects, see README):
    # - Index content, ordered by creation time
    # - Sitemap of content links
    # - Generate RSS feed of content, ordered by creation time
    # - Generate Git bundle asset

    if is_config_attribute "index"; then
        output=$PUBLIC_DIR/index.html
        template=$TEMPLATE_DIR/index.mustache

        if [ ! -e $template ]; then
            perror "Could not generate index.html, missing template $TEMPLATE_DIR/index.mustache"
            exit 1
        fi

        pbold "Writing $output"

        # NOTE: Need to use triple-quote escaping here because my shell's echo
        #       builtin doesn't support the -e flag, and printf fails on the
        #       dashes in the YAML content. So we escape it and dump to stdin.
        cat <<< """$index""" | cat $CONFIG_FILE - | mustache - $template > $output

        if [ $? -eq 0 ]; then
            psuccess "Generated index"
        else
            perror "Failed to generate index"
            exit 1
        fi
    fi

    if is_config_attribute "sitemap"; then
        # Lookup all public markup, including both generated and copied static pages.
        paths=$(find $PUBLIC_DIR -name '*.html')

        # Sitemaps should only contain fully qualified URLs, prefix domain if it's set.
        domain=$(echo_config_attribute "domain")

	# TODO: Validate domain against RFC-3986
        if [ -z $domain ]; then
            pwarning "Blog domain not set in config, can only generate relative URLs"
        fi

        pbold "Writing $OUT_SITEMAP_FILE"

        for path in $paths; do
            echo $domain${path#$PUBLIC_DIR} >> $OUT_SITEMAP_FILE
        done

        psuccess "Generated sitemap"
    fi

    if is_config_attribute "rss"; then
        pwarning "RSS generation not yet implemented."
    fi

    if is_config_attribute "bundle"; then
        if [ -z $(git rev-list -n 1 --all) ]; then
            pwarning "Cannot build a git bundle, no commits have been detected."
        else
            name="$PUBLIC_DIR/$(basename $GIT_BASEDIR).git"

	    pbold "Writing $name"

	    if git bundle create $name --all; then
                psuccess "Generated git bundle"
            else
                perror "Could not create git bundle"
            fi
        fi
    fi
}
