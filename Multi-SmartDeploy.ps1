$MachineName = "dlinazwbtstst0"

For( $i = 2; $i -le 22; $i++ )
{
    .\Smart-Deploy.ps1 -ResourceGroupName "SmartResourcePool" -MachineName "$MachineName$i"
}