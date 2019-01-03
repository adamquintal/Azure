<#
.DESCRIPTION
    This script will traverse through various endpoints on the ms ignite website. Since the endpoints are not documented a try/catch will
    be utilized to attempt to connect to various endpoints. Once an endpoint is hit it will add data to a CSV. Fields added will be:
    Title, Day of Week, Start Hour and Session Type.
#>

$igniteArray = @()
# Attempt to connect to various Session ID endpoints
for ($i = 1000; $i -lt 100000; $i ++)
{
    try
    {
    # Try to open endpoint on ignite api 
    $igniteSession = Invoke-RestMethod -Uri "https://api.myignite.microsoft.com/api/session/anon/$i"
    Write-Host "Session ID found:" $igniteSession.sessionId
    # Build an object of required fields in CSV. 
    $myIgniteSession = "" | Select-Object "Title","Description", "Level", "SessionType", "DayOfTheWeek", "Starthour", "RoomId", "Location"
    # Build object with various fields from API JSON structure 
    $myIgniteSession.title = $igniteSession.title
    $myIgniteSession.level = $igniteSession.level
    $myIgniteSession.description = $igniteSession.description
    $myIgniteSession.dayoftheweek = $igniteSession.dayoftheweek
    $myIgniteSession.starthour = $igniteSession.starthour
    $myIgniteSession.sessiontype = $igniteSession.sessiontype
    $myIgniteSession.RoomId = $igniteSession.RoomId
    $myIgniteSession.Location = $igniteSession.Location
    # Add fields to array
    $igniteArray += $myIgniteSession
    }
    catch{Write-Host "No Session ID at:" $i}
}
# Export data to csv file 
$igniteArray | Export-Csv "C:\ignite.csv"
