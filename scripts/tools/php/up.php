<?php
include('cors.php');
header('Content-Type: text/plain');

$uptime = intval(shell_exec("cut -d. -f1 /proc/uptime"));
$days = floor($uptime/60/60/24);
$hours = $uptime/60/60%24;
$mins = $uptime/60%60;
$secs = $uptime%60;
echo $days."$".$hours."$".$mins."$".$secs;
?>

