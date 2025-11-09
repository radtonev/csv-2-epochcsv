<#
.SYNOPSIS
Converts the 'TimeCreated' column in CSV files to Unix epoch time (in milliseconds) and sorts the data.

.DESCRIPTION
This script iterates through all .csv files in a specified input directory (and its subdirectories),
loads the data, converts the 'TimeCreated' column string to a numerical 'EpochTime' value (milliseconds
since 1970-01-01), adds 'EpochTime' as the first column, and sorts the entire dataset numerically by it.

.PARAMETER indir
The directory path containing the input .csv files. Files will be searched for recursively.

.PARAMETER outdir
The directory path where the resulting CSV files will be saved. Output files will maintain
the original filename structure.

.EXAMPLE
.\csv_to_epoch_csv.ps1 -indir C:\Timelines\RawCSV -outdir C:\Timelines\ProcessedCSV
#>
param (
    [string]$indir = $null,
    [string]$outdir = $null
)

# --- Define Constants ---
# The name of the timestamp column to convert to EpochTime.
$TIME_FIELD_NAME = "TimeCreated"

# Define the Unix Epoch start time (1970-01-01 00:00:00Z)
$UnixEpoch = (Get-Date "1970-01-01 00:00:00Z").ToUniversalTime()

# --- Argument Validation and Help ---
if (!$indir -or !$outdir) {
    Write-Host "Usage: Csv_2_EpochCsv.ps1 -indir <directory with .csv files> -outdir <output directory for .csv files>"
    exit 1
}

# Ensure the input directory exists
if (-not (Test-Path $indir -PathType Container)) {
    Write-Error "Input directory '$indir' does not exist."
    exit 1
}

# Ensure the output directory exists, create if it doesn't
if (-not (Test-Path $outdir -PathType Container)) {
    Write-Host "Output directory '$outdir' does not exist. Creating it."
    New-Item -Path $outdir -ItemType Directory | Out-Null
}

$files = Get-ChildItem -Path $indir -Filter "*.csv" -Recurse

if ($files.Count -eq 0) {
    Write-Host "No .csv files found in $indir (recursively). Exiting."
    exit 0
}

Write-Host ("Found $($files.Count) .csv file(s) to process.")


# --- Main Processing Loop ---
foreach ($file in $files) {
    Write-Host "--------------------------------------------------------"
    Write-Host "Processing file: $($file.Name) (Path: $($file.DirectoryName))"
    
    $infile = $file.FullName
    $output_filepath = Join-Path -Path $outdir -ChildPath $file.Name

    Write-Host "Importing CSV: $($file.Name)"
    try {
        # Import-Csv reads the data, headers are inferred from the first line
        $lines = Import-Csv -Path $infile -Delimiter "," -ErrorAction Stop
    } catch {
        Write-Error "Failed to import CSV file $($file.Name). Error: $($_.Exception.Message)"
        continue
    }

    if ($lines.Count -eq 0) {
        Write-Host "CSV file is empty. Skipping."
        continue
    }
    
    # Check if the required timestamp column exists
    if (-not $lines[0].PSObject.Properties.Name -contains $TIME_FIELD_NAME) {
        Write-Error "CSV file $($file.Name) does not contain a '$TIME_FIELD_NAME' column. Skipping."
        continue
    }

    $processed_lines = @()
    echo "Converting timestamps to EpochTime..."

    foreach ($line in $lines) {
        # 1. Convert TimeCreated string to DateTime object
        try {
            # PowerShell is generally good at parsing standard date formats
            $dateTime = [DateTime]$line.$TIME_FIELD_NAME
            
            # 2. Calculate Epoch Time in Milliseconds
            $TimeCreatedUtc = $dateTime.ToUniversalTime()
            $EpochTimeMs = [long]($TimeCreatedUtc - $UnixEpoch).TotalMilliseconds

            # 3. Add EpochTime property to the current object
            # -PassThru returns the modified object, which is then added to the collection
            $line | Add-Member -MemberType NoteProperty -Name "EpochTime" -Value $EpochTimeMs -PassThru | Out-Null

            $processed_lines += $line
            
        } catch {
            Write-Warning "Failed to parse TimeCreated value '$($line.$TIME_FIELD_NAME)' in file '$($file.Name)'. EpochTime set to 0."
            # Add EpochTime property even if conversion failed (set to 0 for sorting)
            $line | Add-Member -MemberType NoteProperty -Name "EpochTime" -Value 0 -PassThru | Out-Null
            $processed_lines += $line
        }
    }
    
    echo ("Processed $($processed_lines.Count) lines.")

    # --- Column Order and CSV Writing ---
    
    # Determine final column order: EpochTime, TimeCreated, then all others
    $first_object = $processed_lines | Select-Object -First 1
    
    if ($first_object) {
        $fields = @("EpochTime", $TIME_FIELD_NAME)
        # Add all other properties, excluding the ones already added
        $other_fields = $first_object.PSObject.Properties.Name | Where-Object { $_ -ne "EpochTime" -and $_ -ne $TIME_FIELD_NAME }
        $fields += $other_fields
    } else {
        # Fallback if processing yielded no valid lines
        Write-Error "No valid data to export from $($file.Name)."
        continue
    }

    echo "Writing output file to: $output_filepath (Sorted by EpochTime)"

    # Exporting the lines to CSV: Sort by EpochTime, then Select columns in the correct order
    try {
        $processed_lines | Sort-Object -Property EpochTime | Select-Object -Property $fields | Export-Csv -Path $output_filepath -NoTypeInformation -Delimiter "," -Encoding UTF8 -Force
    } catch {
        Write-Error "Failed to write CSV file. Error: $($_.Exception.Message)"
    }
    
    Write-Host "Finished processing $($file.Name)."
}

Write-Host "--------------------------------------------------------"
Write-Host "All files processed successfully."