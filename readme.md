# EDI x12 FHIR Connector

Several Azure services are used to ingest and forward EDI x12 messages to their respective parties along with extracting FHIR resources and storing them in Azure FHIR Service.

## Azure Services

1. Azure Storage Account - Ingestion container for x12 files.
1. Azure Logic App (Standard) - Workflow engine.
1. Azure Integration Account - Business artifacts such as schemas, trading partners, and agreements.

TODO : Include diagram

## Workflow

TODO : Discuss scenario. Discuss workflow ingestion vs outbound messages and ack.

The high level logic flow is as follows:

`ingest > resolve agreement > decode > process ack > process bad/good messages > cleanup and archive`

### Inbound Flow

1. Ingest 837(p|i) from provider
1. Send TA1
1. Extract FHIR data
1. Forward message to payment agency

### Outbound Flow

1. Ingest 999/227/835 from payment agency
1. Extract FHIR data
1. Forward message to provider

### Error Handling



## Deploy

```sh
cd deploy

az deployment group create -g 'hdpa-edi-poc' -f main.bicep --name ("main-" + (Get-Date -Format "s").replace(':', '-')) --parameters `@main.parameters.demo.json
```

## Sample x12 Messages

- [835](/messages/835/835.edi)
- [837p](/messages/837p/X222-ambulance.edi)

## Liquid Templates

[DotLiquid](https://github.com/dotliquid/dotliquid) is used as the template engine to transform the decoded EDI x12 XML data into FHIR resource types. The Azure Logic App [Transform JSON](https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-enterprise-integration-liquid-transform?tabs=consumption) connector is used for the transformation process.

> The template files should be stored under `/logic/Artifacts/Maps` when deploying them to Azure Logic Apps. The name of the file will be used as the reference id in the workflow definition. Consider including a version in the file name.

- [x12Message835ToFhirClaim.liquid](/liquid/x12Message835ToFhirClaim.liquid)

## Considerations

- An SFTP enabled Azure Storage Account can be used to as the drop location for incoming files from external payors. A security container per payor will allow secure access to files specific to the payor. SFTP enabled accounts do not support Event Grid subscriptions to file actions.

## FAQ

- Two common acceptable file extensions for EDI files are `.edi` or `.txt`. The incoming file must be all in 1 line versus each segment per line. This will be treated as a warning and can fail the request.