---
SPDX-License-Identifier: Community-Spec-1.0
tags:
  - reference
  - v3.0
---

# Creating an SPDX 3 extension

This guide walks through creating a custom extension for SPDX 3: when to
create one, how to define it, how to write extension data in an SPDX 3 JSON
document, and how to validate it.

It uses a small example extension, *SyntheticData*, which records how the
content of a dataset was generated (by humans, by a machine, or both).

## Do you need an extension?

An extension adds information to an SPDX Element that the SPDX model has no
property for. Before creating one, check whether you can use something that
already exists:

1. **An existing SPDX property or class.** Check the profiles relevant to your
   data (Software, AI, Dataset, Security, and others). Ask on the SPDX mailing
   lists or open an issue in [spdx/spdx-3-model][spdx-3-model] if you are not
   sure.
2. **An [Annotation][Class_Annotation]**, for a free-text statement about an
   Element, with its own author and date.
3. **A [CdxPropertiesExtension][Class_CdxPropertiesExtension]**, for simple
   name-value pairs, for example to carry CycloneDX `properties`.
4. **A custom extension**, when you need structured data with its own types:
   values from a fixed list, numbers, dates, or references to other Elements.
   That is what this guide covers.

If the information would be useful to others, consider proposing it for a
future SPDX version as well. A working extension is a good basis for such a
proposal.

## Step 1: choose a namespace

Every class and property of your extension is identified by an IRI. Choose a
namespace IRI that you control, for example under your organization's domain:

```text
https://example.org/spdx3-ext/synthetic-data/
```

- Do not use `https://spdx.org/` or another organization's domain.
- Prefer a stable IRI. If you need to make incompatible changes later, put a
  version in the namespace (for example `.../synthetic-data/v2/`).
- Ideally, publish the definition of your extension at that IRI.

## Step 2: design the extension

An extension is a subclass of [Extension][Class_Extension] with its own
properties. Keep it small: one class with a few properties is easier for
others to understand and support.

The SyntheticData extension has five definitions:

| Definition | Kind | Range | Cardinality |
| --- | --- | --- | --- |
| `SyntheticDataExtension` | class, subclass of `Extension` | | |
| `generationMethod` | object property | `DataGenerationMethodType` | 1..1 |
| `DataGenerationMethodType` | vocabulary | `humanGenerated`, `machineGenerated`, `mixed`, `noAssertion` | |
| `syntheticFraction` | data property | `xsd:decimal`, 0 to 1 | 0..1 |
| `generatorModel` | object property | `ai_AIPackage` | 0..* |

Things to decide for each property:

- **Values from a fixed list**: define a vocabulary, with one IRI per entry.
  Include `noAssertion` (or `other`) if a producer may not know the answer.
- **Numbers, dates and other typed values**: choose an XML Schema datatype
  (`xsd:decimal`, `xsd:dateTime`, ...) and any limits.
- **References to SPDX Elements**: use an object property whose range is the
  SPDX class, and refer to the Element by its `spdxId`.
- **Cardinality**: which properties are required, and how many values each may
  have.
- **Several instances on one Element**: an Element may have more than one
  extension, also of the same class. Say whether that is allowed for your
  extension, and what it means.

An extension is not an Element: it has no `spdxId` and no `creationInfo`, and
it belongs to exactly one Element. If the information needs its own identity
or provenance, use an Element (for example an Annotation) instead.

## Step 3: write the definition

Write the definition of your extension in a machine-readable form, so that
tools can check data against it. Use OWL for the classes and properties, and
SHACL for the constraints, in the same style as the
[SPDX model](https://spdx.org/rdf/3.0.1/spdx-model.ttl).

```text
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix sh: <http://www.w3.org/ns/shacl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix spdx-ext: <https://spdx.org/rdf/3.0.1/terms/Extension/> .
@prefix spdx-ai: <https://spdx.org/rdf/3.0.1/terms/AI/> .
@prefix sd: <https://example.org/spdx3-ext/synthetic-data/> .
@prefix sdgm: <https://example.org/spdx3-ext/synthetic-data/DataGenerationMethodType/> .

sd:SyntheticDataExtension a owl:Class, sh:NodeShape ;
    rdfs:subClassOf spdx-ext:Extension ;
    sh:property [
        sh:path sd:generationMethod ;
        sh:in ( sdgm:humanGenerated sdgm:machineGenerated sdgm:mixed sdgm:noAssertion ) ;
        sh:minCount 1 ; sh:maxCount 1 ] ,
    [
        sh:path sd:syntheticFraction ;
        sh:datatype xsd:decimal ;
        sh:minInclusive 0 ; sh:maxInclusive 1 ;
        sh:maxCount 1 ] ,
    [
        sh:path sd:generatorModel ;
        sh:class spdx-ai:AIPackage ] .

sd:DataGenerationMethodType a owl:Class .
sdgm:humanGenerated a owl:NamedIndividual, sd:DataGenerationMethodType .
sdgm:machineGenerated a owl:NamedIndividual, sd:DataGenerationMethodType .
sdgm:mixed a owl:NamedIndividual, sd:DataGenerationMethodType .
sdgm:noAssertion a owl:NamedIndividual, sd:DataGenerationMethodType .

sd:generationMethod a owl:ObjectProperty ; rdfs:range sd:DataGenerationMethodType .
sd:syntheticFraction a owl:DatatypeProperty ; rdfs:range xsd:decimal .
sd:generatorModel a owl:ObjectProperty ; rdfs:range spdx-ai:AIPackage .
```

Add `rdfs:comment` descriptions to every class, property and vocabulary entry.

If you may later propose the extension to SPDX, also write the definitions in
the Markdown format of the [SPDX 3 model][spdx-3-model] (one file per class,
property and vocabulary). That is the format SPDX itself is written in.

## Step 4: use the extension in a document

In SPDX 3 JSON, `@context` must be exactly the SPDX context URL, and that
context only defines SPDX terms. So in an extension object:

- `type` is the **full IRI** of the extension class.
- Property keys are **full IRIs**.
- A value that is an IRI (a vocabulary entry, or a reference to an Element) is
  written as `{"@id": "<IRI>"}`. A plain string is a text value, even if it
  looks like an IRI.
- A value with a datatype other than string, boolean or integer is written as
  `{"@value": "<value>", "@type": "<datatype IRI>"}`. For example, write a
  decimal as `{"@value": "0.35", "@type": "http://www.w3.org/2001/XMLSchema#decimal"}`:
  a JSON number with a fraction, such as `0.35`, means `xsd:double` in
  JSON-LD.
- The extension object is written inside the `extension` array of the Element
  it describes. It cannot be a separate entry in `@graph`.

A complete document, where an AI model generated part of a dataset:

```json
{
  "@context": "https://spdx.org/rdf/3.0.1/spdx-context.jsonld",
  "@graph": [
    {
      "type": "CreationInfo",
      "@id": "_:creationinfo",
      "created": "2026-10-23T00:00:00Z",
      "createdBy": ["https://example.org/spdx/agent/alice"],
      "specVersion": "3.0.1"
    },
    {
      "type": "Person",
      "spdxId": "https://example.org/spdx/agent/alice",
      "name": "Alice Example",
      "creationInfo": "_:creationinfo"
    },
    {
      "type": "SpdxDocument",
      "spdxId": "https://example.org/spdx/doc/synthetic-data",
      "creationInfo": "_:creationinfo",
      "profileConformance": ["core", "software", "ai", "dataset"],
      "rootElement": ["https://example.org/spdx/dataset/instruct-mix"],
      "element": [
        "https://example.org/spdx/agent/alice",
        "https://example.org/spdx/model/teacher-llm",
        "https://example.org/spdx/dataset/instruct-mix",
        "https://example.org/spdx/rel/teacher-generates-dataset"
      ]
    },
    {
      "type": "ai_AIPackage",
      "spdxId": "https://example.org/spdx/model/teacher-llm",
      "name": "teacher-llm",
      "software_packageVersion": "2.1",
      "software_primaryPurpose": "model",
      "creationInfo": "_:creationinfo"
    },
    {
      "type": "dataset_DatasetPackage",
      "spdxId": "https://example.org/spdx/dataset/instruct-mix",
      "name": "instruct-mix",
      "software_packageVersion": "1.0",
      "software_primaryPurpose": "data",
      "dataset_datasetType": ["text"],
      "creationInfo": "_:creationinfo",
      "extension": [
        {
          "type": "https://example.org/spdx3-ext/synthetic-data/SyntheticDataExtension",
          "https://example.org/spdx3-ext/synthetic-data/generationMethod": {
            "@id": "https://example.org/spdx3-ext/synthetic-data/DataGenerationMethodType/mixed"
          },
          "https://example.org/spdx3-ext/synthetic-data/syntheticFraction": {
            "@value": "0.35",
            "@type": "http://www.w3.org/2001/XMLSchema#decimal"
          },
          "https://example.org/spdx3-ext/synthetic-data/generatorModel": {
            "@id": "https://example.org/spdx/model/teacher-llm"
          }
        }
      ]
    },
    {
      "type": "Relationship",
      "spdxId": "https://example.org/spdx/rel/teacher-generates-dataset",
      "from": "https://example.org/spdx/model/teacher-llm",
      "relationshipType": "generates",
      "to": ["https://example.org/spdx/dataset/instruct-mix"],
      "creationInfo": "_:creationinfo"
    }
  ]
}
```

The extension and standard SPDX work together here: the `generates`
Relationship says that the model produced the dataset, and the extension
describes the dataset itself.

### Do not list `extension` in `profileConformance` (SPDX 3.0.x)

In SPDX 3.0.0 and 3.0.1 JSON, the value `"extension"` in `profileConformance`
is expanded by JSON-LD to the `extension` property instead of the `extension`
profile, and fails validation. Writing the full IRI instead is rejected by the
JSON schema. Leave `extension` out of `profileConformance` until this is
fixed.

## Step 5: validate

Validation has two parts.

**SPDX.** Check the document against the SPDX model with
[spdx3-validate](https://github.com/JPEWdev/spdx3-validate):

```shell
spdx3-validate -s 3.0.1 -j synthetic-data.spdx3.json
```

This checks only that the extension fits SPDX (for example, that it is inside
an `extension` array and has a full-IRI `type`). It does not know your
extension's rules.

**Your extension.** Check the extension data against your SHACL shapes, for
example with [pySHACL](https://github.com/RDFLib/pySHACL), passing your
definition as both the shapes and the ontology:

```shell
pyshacl -s synthetic-data.ttl -e synthetic-data.ttl -df json-ld synthetic-data.spdx3.json
```

Test with documents that break your rules too (a missing required property, a
value out of range), and check that they are reported.

### Check that your tools keep the data

Not every SPDX tool supports custom extensions yet. Before you rely on a tool,
read a document with your extension and write it back, and check that:

- the tool does not reject the document;
- the extension object is still there, with the same `type` and keys;
- `{"@id": ...}` and `{"@value": ..., "@type": ...}` values are unchanged;
- the output still passes `spdx3-validate` and your SHACL check.

## Step 6: share the definition

- Publish your OWL/SHACL file, ideally at the namespace IRI, so users and
  validators can find it.
- Document each class, property and vocabulary entry for humans.
- Version it, and keep old versions available.
- If the extension fills a general gap in SPDX, propose it in
  [spdx/spdx-3-model][spdx-3-model], with your definition and examples.

## Summary

| Do | Do not |
| --- | --- |
| Use a namespace you control | Use `https://spdx.org/` or someone else's domain |
| Use full IRIs for the class and properties | Add your own `@context` to the document |
| Write IRI values as `{"@id": ...}` | Write IRIs as plain strings |
| Write decimals and dates as `{"@value": ..., "@type": ...}` | Write decimals as JSON numbers |
| Put the extension inside the Element's `extension` array | Put it at the top level of `@graph` |
| Validate with spdx3-validate **and** your own SHACL | Rely on spdx3-validate alone |

[spdx-3-model]: https://github.com/spdx/spdx-3-model
[Class_Annotation]: https://spdx.github.io/spdx-spec/v3.0.1/model/Core/Classes/Annotation/
[Class_CdxPropertiesExtension]: https://spdx.github.io/spdx-spec/v3.0.1/model/Extension/Classes/CdxPropertiesExtension/
[Class_Extension]: https://spdx.github.io/spdx-spec/v3.0.1/model/Extension/Classes/Extension/
