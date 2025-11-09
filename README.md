# csv-2-epochcsv
Add column Epoch time to a CSV file containg only formated timestamp. Used for easier sorting of events by time.

Modify the  folowing line in the script if the csv that you are trying to process has different name for the timestamp column:

```
# --- Define Constants ---
# The name of the timestamp column to convert to EpochTime.
$TIME_FIELD_NAME = "TimeCreated"
```
