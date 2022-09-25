/*
    Function calling Px Web API to return a dataset. API documentation: https://www.scb.se/contentassets/79c32c72783a4f67b202ad3189f921b9/api_description.pdf
    Px Web API has a limit of 100,000 addresses per call. This function has two core parts:
        An internal function (funcPxWebAPI) that performs the API call. Function expects a YearIdx formatted based on Px Web's requirements.
        A loop part, where YearIdx is incremented by 1 until null records are returned, which in turn calls the API.
*/
let
    func = (
        tableID as text,
        YearIdx as number
    ) as table =>

        let
            funcPxWebAPI = (
                YearIdx as nullable number
            ) as table =>

                let
                    url = "https://pxweb.irena.org:443/api/v1/en/IRENASTAT/Power Capacity and Generation/"
                        & tableID
                        & "_2022_cycle2.px",
                    variable =
                        if (
                            tableID = "RECAP"
                        ) then
                            "Technology"
                        else
                            "Indicator",
                    // Table retrieval query (response, object)
                    jsonQueryBatch1 = "
                                {
                                ""query"": [
                                    {
                                    ""code"": ""Year"",
                                    ""selection"": {
                                        ""filter"": ""item"",
                                        ""values"": [ """
                        & Number.ToText(
                            YearIdx
                        )
                        & """ ]
                                                }
                                    }
                                            ],
                                ""response"": {
                                    ""format"": ""json""
                                            }
                                }
                    
                                ",
                    getPxMetadata = Json.Document(
                        Web.Contents(
                            url
                        )
                    ),
                    variables = getPxMetadata[
                        variables
                    ],
                    convert2Table = Table.FromList(
                        variables,
                        Splitter.SplitByNothing(),
                        null,
                        null,
                        ExtraValues.Error
                    ),
                    expandKeyVals = Table.ExpandRecordColumn(
                        convert2Table,
                        "Column1",
                        {
                            "code",
                            "text",
                            "values",
                            "valueTexts"
                        },
                        {
                            "Column1.code",
                            "Column1.text",
                            "Column1.values",
                            "Column1.valueTexts"
                        }
                    ),
                    addCombinedKeyVal = Table.AddColumn(
                        expandKeyVals,
                        "Custom",
                        each
                            List.Zip(
                                {
                                    [
                                        Column1.values
                                    ],
                                    [
                                        Column1.valueTexts
                                    ]
                                }
                            )
                    ),
                    expandKeyVal = Table.ExpandListColumn(
                        addCombinedKeyVal,
                        "Custom"
                    ),
                    extractedVal = Table.TransformColumns(
                        expandKeyVal,
                        {
                            "Custom",
                            each
                                Text.Combine(
                                    List.Transform(
                                        _,
                                        Text.From
                                    ),
                                    "|"
                                ),
                            type text
                        }
                    ),
                    splitColByDelim = Table.SplitColumn(
                        extractedVal,
                        "Custom",
                        Splitter.SplitTextByDelimiter(
                            "|",
                            QuoteStyle.Csv
                        ),
                        {
                            "Custom.1",
                            "Custom.2"
                        }
                    ),
                    changeDataType = Table.TransformColumnTypes(
                        splitColByDelim,
                        {
                            {
                                "Custom.1",
                                type text
                            },
                            {
                                "Custom.2",
                                type text
                            }
                        }
                    ),
                    renameCol = Table.RenameColumns(
                        changeDataType,
                        {
                            {
                                "Custom.1",
                                "key"
                            },
                            {
                                "Custom.2",
                                "val"
                            }
                        }
                    ),
                    removeCol = Table.RemoveColumns(
                        renameCol,
                        {
                            "Column1.values",
                            "Column1.valueTexts"
                        }
                    ),
                    keyColTable = Table.AddColumn(
                        removeCol,
                        "KeyCol",
                        each
                            Text.Combine(
                                {
                                    [
                                        Column1.code
                                    ],
                                    Text.From(
                                        [
                                            key
                                        ]
                                    )
                                },
                                "|"
                            ),
                        type text
                    ),
                    //POST query to the URL
                    getJsonQuery = Json.Document(
                        Web.Contents(
                            url,
                            [
                                Content = Text.ToBinary(
                                    jsonQueryBatch1
                                )
                            ]
                        )
                    ),
                    getColNames = getJsonQuery[
                        columns
                    ],
                    ColumnsToTable = Table.FromList(
                        getColNames,
                        Splitter.SplitByNothing(),
                        null,
                        null,
                        ExtraValues.Error
                    ),
                    expandColumnsTable = Table.ExpandRecordColumn(
                        ColumnsToTable,
                        "Column1",
                        {
                            "code",
                            "text",
                            "type"
                        },
                        {
                            "Column1.code",
                            "Column1.text",
                            "Column1.type"
                        }
                    ),
                    keyTable = Table.Transpose(
                        Table.SelectColumns(
                            expandColumnsTable,
                            {
                                "Column1.text"
                            }
                        )
                    ),
                    getDataValues = getJsonQuery[
                        data
                    ],
                    convertToTable = Table.FromList(
                        getDataValues,
                        Splitter.SplitByNothing(),
                        null,
                        null,
                        ExtraValues.Error
                    ),
                    expandKeyAndValue = Table.ExpandRecordColumn(
                        convertToTable,
                        "Column1",
                        {
                            "key",
                            "values"
                        },
                        {
                            "Column1.key",
                            "Column1.values"
                        }
                    ),
                    extractKey = Table.TransformColumns(
                        expandKeyAndValue,
                        {
                            "Column1.key",
                            each
                                Text.Combine(
                                    List.Transform(
                                        _,
                                        Text.From
                                    ),
                                    "|"
                                ),
                            type text
                        }
                    ),
                    extractValue = Table.TransformColumns(
                        extractKey,
                        {
                            "Column1.values",
                            each
                                Text.Combine(
                                    List.Transform(
                                        _,
                                        Text.From
                                    ),
                                    "|"
                                ),
                            type text
                        }
                    ),
                    splitKeyByDelim = Table.SplitColumn(
                        extractValue,
                        "Column1.key",
                        Splitter.SplitTextByDelimiter(
                            "|",
                            QuoteStyle.Csv
                        ),
                        {
                            "Column1.key.1",
                            "Column1.key.2",
                            "Column1.key.3"
                        }
                    ),
                    splitValueByDelim = Table.SplitColumn(
                        splitKeyByDelim,
                        "Column1.values",
                        Splitter.SplitTextByDelimiter(
                            "|",
                            QuoteStyle.Csv
                        ),
                        {
                            "Column5"
                        }
                    ),
                    setNulls_a = Table.ReplaceValue(
                        splitValueByDelim,
                        ".",
                        null,
                        Replacer.ReplaceValue,
                        {
                            "Column5"
                        }
                    ),
                    setNulls_b = Table.ReplaceValue(
                        setNulls_a,
                        "..",
                        null,
                        Replacer.ReplaceValue,
                        {
                            "Column5"
                        }
                    ),
                    setNulls_c = Table.ReplaceValue(
                        setNulls_b,
                        "-",
                        null,
                        Replacer.ReplaceValue,
                        {
                            "Column5"
                        }
                    ),
                    setNulls_d = Table.ReplaceValue(
                        setNulls_c,
                        "...",
                        null,
                        Replacer.ReplaceValue,
                        {
                            "Column5"
                        }
                    ),
                    setNulls_e = Table.ReplaceValue(
                        setNulls_d,
                        ",",
                        ".",
                        Replacer.ReplaceText,
                        {
                            "Column5"
                        }
                    ),
                    dataTable = Table.RenameColumns(
                        setNulls_e,
                        {
                            {
                                "Column1.key.1",
                                "Column1"
                            },
                            {
                                "Column1.key.2",
                                "Column2"
                            },
                            {
                                "Column1.key.3",
                                "Column3"
                            },
                            {
                                "Column5",
                                "Column4"
                            }
                        }
                    ),
                    unionTable = Table.Combine(
                        {
                            keyTable,
                            dataTable
                        }
                    ),
                    firstRowAsHeaderFromUnionTable = Table.PromoteHeaders(
                        unionTable
                    ),
                    finalTableKeyCol = Table.AddColumn(
                        firstRowAsHeaderFromUnionTable,
                        "KeyColF",
                        each
                            Text.Combine(
                                {
                                    "Region/country/area",
                                    Text.From(
                                        [
                                            #"Region/country/area"
                                        ]
                                    )
                                },
                                "|"
                            ),
                        type text
                    ),
                    finalTable = Table.Join(
                        finalTableKeyCol,
                        "KeyColF",
                        keyColTable,
                        "KeyCol"
                    ),
                    removeFinalTableCols = Table.RemoveColumns(
                        finalTable,
                        {
                            "Column1.code",
                            "Column1.text",
                            "key",
                            "KeyCol",
                            "KeyColF"
                        }
                    ),
                    curFinalTable = Table.RenameColumns(
                        removeFinalTableCols,
                        {
                            {
                                "Region/country/area",
                                "region_id"
                            },
                            {
                                "val",
                                "Region/country/area"
                            }
                        }
                    ),
                    FinalTable1KeyCol1 = Table.AddColumn(
                        curFinalTable,
                        "KeyColF",
                        each
                            Text.Combine(
                                {
                                    variable,
                                    Text.From(
                                        Record.Field(
                                            _,
                                            variable
                                        )
                                    )
                                },
                                "|"
                            ),
                        type text
                    ),
                    FinalTable2 = Table.Join(
                        FinalTable1KeyCol1,
                        "KeyColF",
                        keyColTable,
                        "KeyCol"
                    ),
                    RemoveFinalTable2Cols = Table.RemoveColumns(
                        FinalTable2,
                        {
                            "Column1.code",
                            "Column1.text",
                            "key",
                            "KeyCol",
                            "KeyColF"
                        }
                    ),
                    Cur2FinalTable = Table.RenameColumns(
                        RemoveFinalTable2Cols,
                        {
                            {
                                variable,
                                "technology_id"
                            },
                            {
                                "val",
                                variable
                            }
                        }
                    ),
                    FinalTable1KeyCol2 = Table.AddColumn(
                        Cur2FinalTable,
                        "KeyColF",
                        each
                            Text.Combine(
                                {
                                    "Year",
                                    Text.From(
                                        [
                                            #"Year"
                                        ]
                                    )
                                },
                                "|"
                            ),
                        type text
                    ),
                    FinalTable3 = Table.Join(
                        FinalTable1KeyCol2,
                        "KeyColF",
                        keyColTable,
                        "KeyCol"
                    ),
                    RemoveFinalTable3Cols = Table.RemoveColumns(
                        FinalTable3,
                        {
                            "Column1.code",
                            "Column1.text",
                            "key",
                            "KeyCol",
                            "KeyColF"
                        }
                    ),
                    Cur3FinalTable = Table.RenameColumns(
                        RemoveFinalTable3Cols,
                        {
                            {
                                "Year",
                                "year_id"
                            },
                            {
                                "val",
                                "Year"
                            }
                        }
                    ),
                    Cur4FinalTable = Table.TransformColumnTypes(
                        Cur3FinalTable,
                        {
                            Table.ColumnNames(
                                Cur3FinalTable
                            ){3},
                            type number
                        }
                    ),
                    outputTable = Table.Sort(
                        Cur4FinalTable,
                        {
                            {
                                "Region/country/area",
                                Order.Ascending
                            },
                            {
                                variable,
                                Order.Ascending
                            },
                            {
                                "Year",
                                Order.Ascending
                            }
                        }
                    ),
                    reorderOutputTable = Table.ReorderColumns(
                        outputTable,
                        {
                            Table.ColumnNames(
                                Cur3FinalTable
                            ){0},
                            Table.ColumnNames(
                                Cur3FinalTable
                            ){4},
                            Table.ColumnNames(
                                Cur3FinalTable
                            ){1},
                            Table.ColumnNames(
                                Cur3FinalTable
                            ){5},
                            Table.ColumnNames(
                                Cur3FinalTable
                            ){2},
                            Table.ColumnNames(
                                Cur3FinalTable
                            ){6},
                            Table.ColumnNames(
                                Cur3FinalTable
                            ){3}
                            // measure
                        }
                    )
                in
                    reorderOutputTable,
            // YearIdx is passed on to funcPxWebAPI each API call
            ListGen = List.Generate(
                () =>
                    [
                        Result = try
                            funcPxWebAPI(
                                YearIdx
                            )
                        otherwise
                            null,
                        YearIdx = YearIdx
                    ],
                each
                    [
                        Result
                    ] <> null,
                each
                    [
                        Result = try
                            funcPxWebAPI(
                                [YearIdx] + 1
                            )
                        otherwise
                            null,
                        YearIdx = [YearIdx] + 1
                    ],
                each
                    [
                        Result
                    ]
            ),
            addYearIdx = Table.Combine(
                ListGen
            ) as table
        in
            addYearIdx,
    // Add documentation
    documentation = type function (
        //
        tableID as (
            type text meta [
                Documentation.FieldCaption = "Table ID",
                Documentation.FieldDescription = "The table to download",
                Documentation.AllowedValues = {
                    "RECAP",
                    "RESHARE"
                }
            ]
        ),
        //
        YearIdx as (
            type number meta [
                Documentation.FieldCaption = "Year Start Index (0 = 2000)"
            ]
        )
    ) as table meta [
        Documentation.Name = "PowerQueryToPxWebAPI",
        Documentation.LongDescription = "
                PxWeb is used for publishing statistics in a database at the web for government
            <br>agencies, international NSIs and international organisations of statistics (e.g. IRENA).
            
            <br>The data can also be accessed via the PxWeb API. Using the API, machine-readable 
            <br>data in various formats including CSV, JSON-stat and PX can be retrieved and 
            <br>used for creating automated dataflows
            <br>
            <br> Table ID: RECAP sources Installed renewable electricity capacity (MW) by Region/country/area, Technology and Year
            <br> Table ID: RESHARE sources Renewable energy share of electricity capacity/generation by Area, Indicator and Year
            ",
        Documentation.Author = "Nichoals Lambert",
        Documentation.Examples = {
            [
                Description = "Source Installed renewable electricity capacity (RECAP) data from IRENASTAT PxWeb API",
                Code = "= PowerQueryToPxWebAPI(""RECAP"", 0)",
                Result = "
| region_id    | Region/country/area |technology_id    | Technology                  | year_id   | Year | Installed renewable energy capacity (MW) | 
|--------------|---------------------|-----------------|-----------------------------------------|-------------------------------------------------|
| GLO          | World               |               1 | Hydropower                  |         0 | 2000 |                              782136.5899 |
| GLO          | World               |               0 | Total renewable energy      |         0 | 2000 |                              752962.5899 |
| GLO          | World               |               2 | Renewable hydropower        |         0 | 2000 |                              697170.0399 |
| RAS          | Asia                |               1 | Hydropower                  |         0 | 2000 |                               196793.822 |
| RER          | Europe              |               1 | Hydropower                  |         0 | 2000 |                               193215.817 |
"
            ]
        }
    ]
in
    Value.ReplaceType(
        func,
        documentation
    )