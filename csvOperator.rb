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
				    	vals << a.to_i
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

def getUnionedKey(dataSet)
	keys = []
	dataSet.each do |file, dataArray|
		dataArray.each do |aData|
			if( aData.has_key?(:key) ) then
				key = aData[:key]
				if !keys.include?( key ) then
					keys << key
				end
			end
		end
	end

	return keys
end

def ensureKeys(dataSet, keys)
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


#---- main --------------------------
options = {
	:source => nil,
	:format => "union,delta",
	:verbose => true,
	:topX => 0,
	:csvOutput => nil,
}

opt_parser = OptionParser.new do |opts|
	opts.banner = "Usage: --source=dataset1.csv;dataset2.csv --format=[union],[delta|sum] ... (options)"

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

# ensure dataSey with unioned keys
keys = getUnionedKey(dataSet)
dataSet = ensureKeys(dataSet, keys)

# for union (print inputed CSV datas)
result = {}
dataSet.each do |file, dataArray|
	dataArray.each do |aData|
		if( aData.has_key?(:key) ) then
			key = aData[:key].to_s
			vals = aData[:vals].to_a

			if options[:format].include?("union") then
				if !result.has_key?( key ) then
					result[ key ] = vals
				else
					result[ key ] = result[ key ] + vals
				end
			end
		end
	end
end

# for operation
operations = options[:format].split(",")
if operations then
	keys.each do |aKey|
		operatedResult = operateData(getTargetData(dataSet, aKey), operations)
		result[ aKey ] = result[ aKey ].to_a + operatedResult if operatedResult.length
	end
end

# remove all zero
result2 = {}
result.each do |key, vals|
	flag = false
	vals.each do |aVal|
		if aVal.to_i!=0 then
			flag=true
			break
		end
	end
	if flag then
		result2[key] = vals
	end
end
result = result2


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
