# csvOperator

## csvInserter

```dic.csv
keyA,valueA
keyB,valueB
keyC,valueC
```

```dataSet.csv
keyA,miscData,miscData
keyB,miscData,miscData
keyC,miscData,miscData
```

```
$ ruby csvInserter.rb -d dic.csv -s dataSet.csv
```

result is
```
keyA,miscData,miscData,valueA
keyB,miscData,miscData,valueB
keyC,miscData,miscData,valueC
```

In short, you can add corresponding value which is defined in the ```dic.csv```

## csvOperator

```
$ ruby csvOperator.rb --help
Usage: --source=dataset1.csv;dataset2.csv --format=[and|union],[delta|sum] ... (options)
    -s, --source=                    Specify source files (data1.csv,data2.csv)
    -f, --format=                    Specify format (default:union,delta)
    -q, --quiet                      suppress verbose status output (default verbose)
    -c, --csvOutput=                 Specify output CSV filename'
    -t, --top=                       Get top X'
```