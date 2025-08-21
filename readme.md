DAG:

```mermaid
flowchart TB
    subgraph " "
    subgraph params
    v4["input"]
    v11["bigstitcher"]
    v28["brainreg"]
    v0["fiji_cache_dir"]
    end
    v2([setupFiji])
    v9([stageFilesRSync])
    v10([makeCziDatasetForBigstitcher])
    v12([alignChannelsWithBigstitcher])
    v14([alignTilesWithBigstitcher])
    v16([icpRefinementWithBigstitcher])
    v19([reorientToASRWithBigstitcher])
    v23([fuseBigStitcherDataset])
    v26([getVoxelSizes])
    v29([organizeChannelsForBrainreg])
    v37([brainregEnvInstall])
    v39([downloadAtlas])
    v41([brainregRunRegistration])
    v2 --> v10
    v9 --> v10
    v2 --> v12
    v10 --> v12
    v11 --> v12
    v2 --> v14
    v11 --> v14
    v12 --> v14
    v2 --> v16
    v11 --> v16
    v14 --> v16
    v16 --> v19
    v2 --> v19
    v11 --> v19
    v16 --> v23
    v2 --> v23
    v11 --> v23
    v2 --> v26
    v23 --> v26
    v23 --> v29
    v28 --> v29
    v37 --> v39
    v28 --> v39
    v37 --> v41
    v39 --> v41
    v26 --> v41
    v28 --> v41
    v29 --> v41
    end
```

Note: to use nextflow on SCITAS cluster, you need the Java module:
// module --show-hidden av 

module load openjdk/21.0.0_35-h27dssk 

module --show-hidden av 

https://www.nextflow.io/docs/latest/install.html#self-install

Example command line:

nextflow run main.nf -resume -profile local --input test_da
ta/ExampleMultiChannel.czi -with-trace