# str_load.jl
#
# Jeremy Rüffer
# Thünen Institut
# Institut für Agrarklimaschutz
# Junior Research Group NITROSPHERE
# Julia 0.6.1
# 16.12.2016
# Last Edit: 14.12.2017

"""# str_load

Load data from Aerodye STR files generated by TDLWintel

---

### Examples

`time,D = str_load(\"K:\\\\Data\\\\140113_135354.str\")`\n
`time,D = str_load([\"K:\\\\Data\\\\140113_135354.str\",\"K:\\\\Data\\\\140114_000000.str\"])`\n
`time,D = str_load(\"K:\\\\Data\\\\\")` # Load all STR files in the given directory and subdirectories\n
`time,D = str_load(\"K:\\\\Data\\\\\",verbose=true,cols=[\"Traw\",\"X1\"])` # Load only Traw and X1 from all files in the given directory and display information as it is processed\n
`time,D = str_load(\"K:\\\\Data\\\\\",DateTime(2014,6,27,11,58,0))` # Load files starting at the given timestamp\n
`time,D = str_load(\"K:\\\\Data\\\\\",DateTime(2014,6,27,11,58,0),DateTime(2014,7,4,12,0,0))` # Load files between the given timestamps\n

---

`time, D = str_load(F)`\n
* **time**::Array{DateTime,1} = Parsed time values from the STR file
* **D**::DataFrame = Data from the STR file
* **F**::Array{String,1} = Array of STR files to load

`time, D = str_load(F;verbose=false,cols=[])`\n
* **timeStr**::Array{DateTime,1} =
* **F**::String = File name and location
* **verbose**::Bool (optional) = Display what is happening, FALSE is default
* **cols**::Array{String,1} or Array{Symbol,1} (optional) = List of columns to return, [] is default

`time, D = str_load(F,mindate;verbose=false,cols=[])`\n
`time, D = str_load(F,mindate,maxdate;verbose=false,cols=[])`\n
* **mindate**::DateTime = Load files including and after this date and time
* **maxdate**::DateTime = Load files up to this date and time
"""
function str_load(Dr::String,mindate::DateTime;verbose::Bool=false,cols::Array{String,1}=String[],recur::Int=9999)
	## Load STR files in the given directory (Dr) including and beyond the given date ##
	return str_load(Dr,mindate,DateTime(9999,1,1,0,0,0);verbose=verbose,cols=cols,recur=recur)
end # End of str_load(Dr::String,mindate::DateTime;verbose::Bool=false,cols::Array{String,1}=String[],recur::Int=9999)

function str_load(Dr::String,mindate::DateTime,maxdate::DateTime;verbose::Bool=false,cols::Array{String,1}=String[],recur::Int=9999)
	## Load STR files in the given directory (Dr) between the given dates ##
	
	# Check for Directory
	if isdir(Dr) == false
		error("First input should be a directory")
	end
	
	# List Files
	verbose ? println("Listing Files") : nothing
	(Fstr,folders) = dirlist(Dr,regex=r"\d{6}_\d{6}\.str$",recur=recur) # List STR files
	
	# Parse Times
	(Tstr,Fstr) = aerodyne_parsetime(Fstr)
	
	# Sort Info
	f = sortperm(Tstr)
	Tstr = Tstr[f]
	Fstr = Fstr[f]
	
	# Remove Files Out of Range
	begin
		# STR Files
		f = findin(Tstr .== mindate,true)
		if isempty(f)
			f = findin(Tstr .< mindate,true)
			if isempty(f)
				f = 1
			else
				f = f[end]
			end
		else
			f = f[1]
		end
		Tstr = Tstr[f:end]
		Fstr = Fstr[f:end]
		f = Tstr .< maxdate
		Tstr = Tstr[f]
		Fstr = Fstr[f]
	end
	
	# Load Data
	if verbose
		println("Loading:")
	end
	(Tstr,Dstr) = str_load(Fstr,verbose=verbose,cols=cols)
	
	# Remove Time Values Out of Range
	begin
		f = Tstr .>= mindate
		Tstr = Tstr[f]
		Dstr = Dstr[f,:]
		f = Tstr .<= maxdate
		Tstr = Tstr[f]
		Dstr = Dstr[f,:]
	end
	
	return Tstr,Dstr
end # End of str_load(Dr::String,mindate::DateTime,maxdate::DateTime;verbose::Bool=false,cols::Array{String,1}=String[],recur::Int=9999)

function str_load{T<:String}(F::Array{T,1};verbose::Bool=false,cols::Array{String,1}=String[])
	## Load a list of file names ##
	
	# Sort files by dates
	(Ftime,F) = aerodyne_parsetime(F)
	
	# Load and concatinate data
	(t,D) = str_load(F[1],verbose=verbose,cols=cols) # Initial load
	for i=2:1:length(F)
		(tempT,tempD) = str_load(F[i],verbose=verbose,cols=cols)
		t = [t;tempT]
		D = [D;tempD]
	end
	
	return t,D
end # End str_load{T<:String}(F::Array{T,1};verbose::Bool=false,cols::Array{String,1}=String[])

function str_load(F::String;verbose::Bool=false,cols::Array{String,1}=String[])
	ext = F[rsearch(F,'.') + 1:end] # Save the extension
	
	verbose ? println("  " * F) : nothing
	
	## Check for a proper file
	if isempty(ext) == true
		error("No file extension")
	elseif isdir(F) == true
		return str_load(F,DateTime(0,1,1,0,0,0),DateTime(9999,1,1,0,0,0),verbose=verbose,cols=cols)
	elseif ext != "str"
		error("Extension is not STR. Returning nothing...")
		return
	end
	
	#################
	##  Load Data  ##
	#################
	## Load Header Information
	fid = open(F,"r")
	h1 = readline(fid)
	h1 = h1[rsearch(h1,"SPEC:")[end]+1:end] # Remove everything including and before the SPEC:
	h2 = readcsv(IOBuffer("\"" * replace(h1,",","\",\"") * "\""))
	h = Array{String}(length(h2) + 2)
	h[1] = "time"
	h[end] = "Empty"
	for i=1:1:length(h2)
		h[i+1] = strip(String(h2[i])) # Remove leading and trailing whitespace
		h[i+1] = replace(h[i+1]," ","_") # Replace remaining whitespace with _
	end
	close(fid)
	
	## Check for duplicate column names and adjust them
	unames = unique(h) # unique column names
	for i in unames
		check = 0
		for j = 1:length(h)
			if i == h[j]
				check += 1
				
				if check > 1
					h[j] = h[j] * "-" * string(check)
				end
			end
		end
	end
	
	## List column types
	coltypes = Any[Float64 for i=1:length(h)]
	for i=1:1:length(h)
		if h[i] == "SPEFile"
			coltypes[i] = Union{Missing,String}
		end
		
		if h[i] == "StatusW"
			coltypes[i] = Int
		end
	end
	
	## Todo: Replace column names with reasonable names
	
	## Load data
	D = DataFrame()
	try
		#D = DataFrames.readtable(F,eltypes = coltypes,separator = ' ',header = false,skipstart = 2*1)
		D = CSV.read(F;delim=" ",header=h,datarow=2)[:,1:end-1]
	catch
		println("Cannot load " * F)
		error("ERROR loading files")
	end
	
	#########################
	##  Parse Time Format  ##
	#########################
	time = Array{DateTime}(length(D[:time])) # Preallocate time column
	secs = Dates.Second # Initialize so it doesn't have to do it every time in the loop
	millisecs = Dates.Millisecond # Initialize so it doesn't have to do it every time in the loop
	for i=1:1:length(D[:time])
		secs = Dates.Second(floor(D[:time][i]))
		millisecs = Dates.Millisecond(floor(1000(D[:time][i] - floor(D[:time][i]))))
		time[i] = DateTime(1904,1,1,0,0,0) + secs + millisecs
	end
	
	##################################
	##  Keep only selected columns  ##
	##################################
	if !isempty(cols)
		# Check cols' type
		if typeof(cols) != Array{Symbol,1} && typeof(cols) != Symbol
			temp = Array{Symbol}(length(cols))
			for i=1:1:length(cols)
				temp[i] = Symbol(cols[i]) # Convert all the values to symbols
			end
			cols = temp
		end
		
		# Make sure each entry exists
		fields = names(D)
		cols_bool = fill!(Array{Bool}(length(cols)),false) # Preallocate false
		for i=1:1:length(cols)
			for j=1:1:length(fields)
				if fields[j] == cols[i]
					cols_bool[i] = true
				end
			end
		end
		cols = cols[cols_bool]
		
		# Remove Unwanted column
		if isempty(cols)
			D = DataFrame()
			time = Array{DateTime}(0)
		else
			D = D[cols]
		end
	end
	
	return time,D
end # End of str_load(F::String;verbose::Bool=false,cols::Array{String,1}=String[])
