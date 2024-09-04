#! /bin/bash
#
# Validates SPDX example, both in separate files and inline in the
# documentation
#
# SPDX-License-Identifier: MIT

set -e

THIS_DIR=$(dirname $0)
SCHEMA_FILE="https://spdx.org/schema/3.0.0/spdx-json-schema.json"
RDF_FILE="https://spdx.org/rdf/3.0.0/spdx-model.ttl"
CONTEXT_FILE="https://spdx.org/rdf/3.0.0/spdx-context.jsonld"
SPDX_VERSION="3.0.0"

check_schema() {
    check-jsonschema \
        -v \
        --schemafile $SCHEMA_FILE \
        "$1"
}

check_model() {
    pyshacl \
        -s $RDF_FILE \
        -e $RDF_FILE \
        "$1"
}

if [ "$(ls $THIS_DIR/../docs/examples/jsonld/*.json 2>/dev/null)" ]; then
    for f in $THIS_DIR/../docs/examples/jsonld/*.json; do
        echo "Checking $f"
        check_schema $f
        check_model $f
    done
fi

for f in $THIS_DIR/../docs/*.md; do
    if ! grep -q '^```json' $f; then
        continue
    fi
    echo "Checking $f"
    DEST=$T/$(basename $f)
    mkdir -p $DEST

    cat $f | awk -v DEST="$DEST" 'BEGIN{flag=0} /^```json/, $0=="```" { if (/^---$/){flag++} else if ($0 !~ /^```.*/ ) print $0 > DEST "/doc-" flag ".spdx.json"}'

    echo "[" > $DEST/combined.json

    for doc in $DEST/*.spdx.json; do
        if ! grep -q '@context' $doc; then
            mv $doc $doc.fragment
            cat >> $doc <<HEREDOC
{
    "@context": "$CONTEXT_FILE",
    "@graph": [
HEREDOC
            cat $doc.fragment >> $doc
            cat >> $doc <<HEREDOC
        {
            "type": "CreationInfo",
            "@id": "_:creationInfo",
            "specVersion": "$SPDX_VERSION",
            "created": "2024-04-23T00:00:00Z",
            "createdBy": [
                {
                    "type": "Agent",
                    "spdxId": "http://spdx.dev/dummy-agent",
                    "creationInfo": "_:creationInfo"
                }
            ]
        }
    ]
}
HEREDOC
        fi
        check_schema $doc
        cat $doc >> $DEST/combined.json
        echo "," >> $DEST/combined.json
    done

    echo "{}]" >> $DEST/combined.json

    check_model $DEST/combined.json
done
