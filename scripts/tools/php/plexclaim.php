<?php
include('cors.php');
//header('Content-Type: application/json');

$token = "test";

if (isset($_POST['token']))
{
    $token = $_POST['token'];
    echo "token: '" . $token."'\n";
}

if ($token != null)
{
    $out = shell_exec("sudo -u plex /srv/tools/plexclaim.sh " . $token);
    echo "out: '" . $out."'\n";
    if (strpos($out, 'success') !== false) {
        echo "Plex server claimed successfully using token '".$token."'\n";
    }
    else
    {
        echo "no response for token: '".$token."'\n";
    }
}
else
{
    echo "invalid token: '".$token."'\n";
}