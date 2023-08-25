#!/usr/bin/env ruby
#  Copyright (C) 2022, 2023 hidenorly
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


def numericString?(str)
	result = false
	begin
		Float(str)
		result = true
	rescue ArgumentError, TypeError
		result = false
	end
	return result
end

def loadCSV(path)
	data=[]
	if File.exist?(path) then
		File.open(path) do |file|
			file.each_line do |aLine|
				if( aLine.valid_encoding? ) then
				    row = aLine.to_s.split(",").to_a
				    theCols = []
				    row.each do |aCol|
				    	theCols << aCol.strip
				    end
				    data.push( theCols )
				end
			end
		end
	end
	return data
end

def ensureDatasetWithKeysForInject(dataSet, _dicSet)
	result = []
	dicSet = _dicSet.to_h
  dataSet.to_h.each do |file, dataArray|
		dataArray.each do |aData|
			if dicSet.include?(aData[0]) then
				aData.push( dicSet[aData[0]] )
			end
			result.push(aData)
		end
	end

	return result
end


#---- main --------------------------
options = {
	:source => nil,
	:dic => nil
}

opt_parser = OptionParser.new do |opts|
	opts.banner = "Usage: --source=dataset1.csv;dataset2.csv"

	opts.on("-s", "--source=", "Specify source files (data1.csv,data2.csv)") do |source|
		options[:source] = source
	end

	opts.on("-d", "--dictionary=", "Specify dictionary file (dic.csv)") do |dic|
		options[:dic] = dic
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

dicSet = {}
if options[:dic] then
	dicSet = loadCSV(options[:dic])
end

# result
result = []
result = ensureDatasetWithKeysForInject(dataSet, dicSet)

i = 0
result.each do |aCols|
	aCols.each do |aCol|
		aCol.strip!
		print(aCol+",")
	end
	puts ""
end