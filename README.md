# csvOperator

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
ruby csvInserter.rb -d dic.csv -s dataSet.csv
```

result is
```
keyA,miscData,miscData,valueA
keyB,miscData,miscData,valueB
keyC,miscData,miscData,valueC
```

In short, you can add corresponding value which is defined in the ```dic.csv```