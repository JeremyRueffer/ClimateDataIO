# csci_textload.jl
#
#	Load Campbell Scientific TOA5 files
#
# Jeremy Rüffer
# Thünen Institut
# Institut für Agrarklimaschutz
# Junior Research Group NITROSPHERE
# Julia 0.5.0
# Created: 04.11.13
# Last Edit: 12.12.16

"""# csci_textload

Load TOA5 data files generated by Campbell Scientific dataloggers

---

### Examples

`data = csci_textload(\"K:\\\\Data\\\\AirTemp.dat\")` Load the data from the file into a dataframe, data, converting time columns to DateTimes

`data = csci_textload([\"K:\\\\Data\\\\AirTemp_20141219-000000.dat\",\"K:\\\\Data\\\\AirTemp_20141220-000000.dat\"])` Load a list of similarly formatted files

`data = csci_textload(\"K:\\\\Data\",\"MetData_AirTemp\")` Load a directory of data which start with \"MetData_AirTemp\"

`data = csci_textload(\"K:\\\\Data\",\"MetData_AirTemp\",DateTime(2014,12,18))` Load a directory of data starting at 18.12.2014

`data = csci_textload(\"K:\\\\Data\",\"MetData_AirTemp\",DateTime(2014,12,18),DateTime(2014,12,19,12))` Load a directory of data from 18.12.2014 to 12:00 on 19.12.2014

`(data,logger_Str,columns_Str,units_Str,type_Str) = csci_textload(\"K:\\\\Data\\\\AirTemp.dat\",headerout = true)`

---

`data = csci_textload(F;headerlines=4,headeroutput=false,verbose=true,strlist=[],intlist=[],timelist=[])`\n
* **data**::DataFrame = Loaded data, including a fully parsed time column
* **F**::String or Array{String,1} = File or an array of files to load
* **headerlines**::Int (optional) = Number of header lines, 4 is default
* **headeroutput**::Bool (optional) = Add four header lines to output, FALSE is default
* **verbose**::Bool (optional) = Display information about what is happening when set to TRUE, TRUE is default
* **strlist**::Array{String} (optional) = List of column names that should be strings, [] is default
* **intlist**::Array{String} (optional) = List of column names that should be integers, [] is default
* **timelist**::Array{String} (optional) = List of column names that should be DateTime values, [] is default
\n\n
`data = csci_textload(F,`rootname`;headerlines=4,headeroutput=false,verbose=true,recur=2,strlist=[],intlist=[],timelist=[])`\n
`data = csci_textload(F,rootname,`mindate`;headerlines=4,headeroutput=false,verbose=true,recur=2,strlist=[],intlist=[],timelist=[])`\n
`data = csci_textload(F,rootname,mindate,`maxdate`;headerlines=4,headeroutput=false,verbose=true,recur=2,strlist=[],intlist=[],timelist=[])`\n
* **F**::String = Directory of files to load
* **rootname**::String = Root of the file names to process, \"Dedelow_CR3000\" is the root of \"Dedelow_CR3000_Soil.dat\", \"Dedelow_CR3000_Temperature\", etc.
* **mindate**::DateTime = Load files including and after this date and time
* **maxdate**::DateTime = Load files up to this date and time"""
function csci_textload(F::String,rootname::String,mindate::DateTime=DateTime(0),maxdate::DateTime=DateTime(9999);headerlines::Int=4,headeroutput::Bool=false,verbose::Bool=true,recur::Int=2,strlist::Array{String,1}=String[],intlist::Array{String,1}=String[],timelist::Array{String,1}=String[])
	# Check
	if !isfile(F) & !isdir(F)
		error("First input must be a valid file or directory. For a single file use csci_textread.")
	end

	# Load a directory of data
	(files,folder) = dirlist(F,regex=r"\.dat$",recur=recur)

	# Find files only with the root name
	filebase = ""
	keepers = Array(Bool,length(files))
	for i=1:1:length(files)
		keepers[i] = ismatch(Regex(rootname),basename(files[i]))
	end
	files = files[keepers]

	# Files Timestamp Conversion
	(mintimes,maxtimes) = csci_times(files)
	f = sortperm(mintimes)
	files = files[f]
	mintimes = mintimes[f]
	maxtimes = maxtimes[f]

	# Remove Files Out of Range
	f1 = Array(Bool,length(files))
	for i=1:1:length(files)
		f1[i] = (mintimes[i] <= mindate < maxtimes[i]) | (mintimes[i] <= maxdate < maxtimes[i])
	end
	f = (mindate .<= mintimes .< maxdate) | (mindate .<= maxtimes .< maxdate) | f1
	files = files[f]
	mintimes = mintimes[f]
	maxtimes = maxtimes[f]

	# Convert to Array{String,1}
	temp = Array(String,length(files))
	for i=1:1:length(files)
		temp[i] = files[i]
	end
	files = temp

	if headeroutput
		(D,loggerStr,colsStr,unitsStr,processingStr) = csci_textload(files,headerlines=headerlines,headeroutput=headeroutput,verbose=verbose,strlist=strlist,intlist=intlist,timelist=timelist)

		# Remove Values Still Out of Range
		f = find(mindate .<= D[1] .< maxdate)
		D = D[f,:]

		return D, loggerStr, colsStr, unitsStr, processingStr
	else
		D = csci_textload(files,headerlines=headerlines,headeroutput=headeroutput,verbose=verbose,strlist=strlist,intlist=intlist,timelist=timelist)

		# Remove Values Still Out of Range
		f = find(mindate .<= D[1] .< maxdate)
		D = D[f,:]

		return D
	end
end

function csci_textload{T<:String}(F::Array{T,1};headerlines::Int=4,headeroutput::Bool=false,verbose::Bool=true,strlist::Array{String,1}=String[],intlist::Array{String,1}=String[],timelist::Array{String,1}=String[])
	D = DataFrame[]
	loggerStr = ""
	colsStr = ""
	unitsStr = ""
	processingStr = ""

	# Load the list of files
	tempD = DataFrame[]
	for i=1:1:length(F)
		if headeroutput
			(tempD,loggerStr,colsStr,unitsStr,processingStr) = csci_textread(F[i],headerlines=headerlines,headeroutput=headeroutput,verbose=verbose,strlist=strlist,intlist=intlist,timelist=timelist)
		else
			(tempD) = csci_textread(F[i],headerlines=headerlines,headeroutput=headeroutput,verbose=verbose,strlist=strlist,intlist=intlist,timelist=timelist)
		end

		if isempty(D)
			D = tempD
		else
			D = [D;tempD]
		end
	end

	# Output Results
	if headeroutput
		return D, loggerStr, colsStr, unitsStr, processingStr
	else
		return D
	end
end
