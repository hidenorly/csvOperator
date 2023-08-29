#!/usr/bin/env ruby
#  Copyright (C) 2023 hidenorly
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'optparse'
require 'csv'

OPERATION_NONE = 0
OPERATION_UNION = 1
OPERATION_AND = 2


def outputCSV(result, path, verbose)
	if path != nil then
		fileWriter = File.open(path, "w")
	else
		fileWriter = nil
	end
	result.each do |k,v|
		if v.length !=0 then
			data = ""
			v.each do |aData|
				data = "#{data},#{aData}"
			end
			outBuf = "#{k}#{data}"
			puts outBuf if verbose
			fileWriter.puts outBuf if fileWriter
		end
	end
	if fileWriter then
		fileWriter.close
	end
end


def loadCSV(path)
	data=[]
	if File.exist?(path) then
		File.open(path) do |file|
			file.each_line do |aLine|
				if( aLine.valid_encoding? ) then
					row = aLine.split(",")
					key = row[0].strip
					tmp = row.drop(1)
					vals=[]
					tmp.each do |a|
						vals << a.strip #.to_i
					end
					data << {:key=>key.to_s, :vals=>vals.to_a}
				end
			end
		end
	end
	return data
end

def getTargetData(dataSet, key)
	result=[]
	dataSet.each do |file, dataArray|
		# keyedData = dataArray.find { |aData| aData[:key] == key }
		dataArray.each do |aData|
			if aData[:key] == key then
				aData[:vals].each do |aVal|
					result << aVal
				end
			end
		end
	end
	return result
end

# 最初の要素から、次以降の要素に対してSUM/SUBする
# =data[0]-sum(data[1]...data[N]), =data[0]+sum(data[1]...data[N])
def operateData(data, operations)
	result = []
	operations.each do |anOperation|
		case anOperation
			when "delta" then
				tmp = data[0]
				tmp2 = data.drop(1)
				tmp2.each do |aVal|
					tmp = tmp - aVal
				end
				result.push(tmp)
			when "sum" then
				tmp = data[0]
				tmp2 = data.drop(1)
				tmp2.each do |aVal|
					tmp = tmp + aVal
				end
				result.push(tmp)
		end
	end
	return result.to_a
end


def getOperatedKeys(dataSet, operationMode)
	keys = []
	dataSet.each do |file, dataArray|
		tmpKeys = []
		dataArray.each do |aData|
			if( aData.has_key?(:key) ) then
				key = aData[:key]
				if !tmpKeys.include?( key ) then
					tmpKeys << key
				end
			end
		end
		keys << tmpKeys if tmpKeys.length>0
	end

	result = keys[0]
	for i in 1..(keys.length-1) do
		case operationMode
			when OPERATION_UNION then
				result = result | keys[i]
			when OPERATION_AND then
				result = result & keys[i]
		end
	end

	return result
end

# --- for and ------
def ensureDatasetWithKeysForAnd(dataSet, keys)
	dataSet.each do |file, dataArray|
		newDataArray = []
		dataArray.each do |aData|
			if keys.include?(aData[:key]) then
				newDataArray << aData
			end
		end
		dataSet[file] = newDataArray
	end

	return dataSet
end


# --- for union ------
# dataSetは[csvFileName] = dataの配列 (:key(string), :vals(array))になっている
# keysは、全dataSetのkeyの和集合
# dataSetのdataの配列の中を探索して、keyに漏れがあった場合は、dataSet[そのcsvFilename]に、
# :key=>そのkey, :vals=>0...のarrayを追加することで各dataSet[csvFilename]のkeyがensureされるようにする
def ensureDatasetWithKeysForUnion(dataSet, keys)
	dataSet.each do |file, dataArray|
		missingKeys = []
		dataNumMax = 0
		keys.each do |aKey|
			flag = false
			dataArray.each do |aData|
				if aData[:vals].length > dataNumMax then
					dataNumMax = aData[:vals].length
				end
				if aData[:key] == aKey then 
					flag = true
					break
				end
			end
			if !flag then
				missingKeys << aKey
			end
		end
		zeroArray = []
		for i in 1..dataNumMax do
			zeroArray << 0
		end
		missingKeys.each do |aKey|
			dataArray << {:key=>aKey, :vals=>zeroArray}
		end
	end

	return dataSet
end

def addOriginalDataToResult(dataSet, result)
	dataSet.each do |file, dataArray|
		dataArray.each do |aData|
			if( aData.has_key?(:key) ) then
				key = aData[:key].to_s
				vals = aData[:vals].to_a

				if !result.has_key?( key ) then
					result[ key ] = vals
				else
					result[ key ] = result[ key ] + vals  # array + array (= unioned array)
				end
			end
		end
	end
end

# --- utility
def removeAllZero(result)
	result2 = {}
	result.each do |key, vals|
		flag = false
		vals.each do |aVal|
			if aVal.to_i!=0 || aVal.to_f!=0.0 then
				flag=true
				break
			end
		end
		if flag then
			result2[key] = vals
		end
	end
	return result2
end


#---- main --------------------------
options = {
	:source => nil,
	:format => "union,delta",
	:verbose => true,
	:topX => 0,
	:csvOutput => nil,
}

opt_parser = OptionParser.new do |opts|
	opts.banner = "Usage: --source=dataset1.csv;dataset2.csv --format=[and|union],[delta|sum] ... (options)"

	opts.on("-s", "--source=", "Specify source files (data1.csv,data2.csv)") do |source|
		options[:source] = source
	end

	opts.on("-f", "--format=", "Specify format (default:union,delta)") do |format|
		options[:format] = format
	end

	opts.on("-q", "--quiet", "suppress verbose status output (default verbose)") do |verbose|
		options[:verbose] = false
	end

	opts.on("-c", "--csvOutput=", "Specify output CSV filename'") do |csvOutput|
		options[:csvOutput] = csvOutput
	end

	opts.on("-t", "--top=", "Get top X'") do |topX|
		options[:topX] = topX.to_i
	end
end.parse!


# check path
if !options[:source] then
	puts "Please specify --source=dataset1.csv,dataset2.csv"
	exit(-1)
end


# load csv datas
files = options[:source].to_s.split(",")
dataSet = {}
files.each do |aFile|
	dataSet[aFile] = loadCSV(aFile)
end

# result
result = {}

# check mode
operationMode = OPERATION_UNION
enableOutputOriginalData = false
if options[:format].include?("union") then
	operationMode = OPERATION_UNION
	enableOutputOriginalData = !options[:format].include?("(union)")
elsif options[:format].include?("and") then
	operationMode = OPERATION_AND
	enableOutputOriginalData = !options[:format].include?("(and)")
end

# get unioned/and-ed keys
keys = getOperatedKeys(dataSet, operationMode)


# filter dataSet with unioned/and-ed keys
case operationMode
	when OPERATION_UNION then
		# ensure dataSey with unioned keys
		dataSet = ensureDatasetWithKeysForUnion(dataSet, keys)

	when OPERATION_AND then
		# ensure dataSey with and-ed keys
		dataSet = ensureDatasetWithKeysForAnd(dataSet, keys)
end

# store data to print inputed CSV datas
addOriginalDataToResult(dataSet, result) if enableOutputOriginalData


# for operation
operations = options[:format].split(",")
if operations then
	keys.each do |aKey|
		operatedResult = operateData(getTargetData(dataSet, aKey), operations)
		result[ aKey ] = result[ aKey ].to_a + operatedResult if operatedResult.length
	end
end


# remove all zero
result = removeAllZero(result)


# sort TODO: use n-th data in vx
result = result.sort do |(k1,v1),(k2,v2)|
	ret = v2[0] <=> v1[0]
	ret == 0 ? k1 <=> k2 : ret
end

# get top X
if options[:topX].to_i!=0 then
	result = result.take(options[:topX].to_i)
end

# Convert result to CSV file
outputCSV(result, options[:csvOutput], options[:verbose])
