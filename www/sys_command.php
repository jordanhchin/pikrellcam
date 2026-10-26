<?php
	require_once(dirname(__FILE__) . '/config.php');
	require_once(dirname(__FILE__) . '/security.php');
?>
<?php
	pkc_require_method(array("PUT", "POST"));
	pkc_require_same_origin();

// pikrellcam runs as a systemd service (installed by install-pikrellcam.sh)
// and www-data has sudo permission only to start or stop that service.
//
if (isset($_GET['cmd']))
	{
	$cmd = $_GET['cmd'];

	if ($cmd === "pikrellcam_start")
		{
		exec("pgrep -x pikrellcam", $output, $return);
		if ($return != 0)
			exec("sudo -n /bin/systemctl start pikrellcam > /dev/null 2>&1");
		}
	else if ($cmd === "pikrellcam_stop")
		{
		// "quit" also stops a pikrellcam started from a terminal.
		$fifo = fopen(FIFO_FILE,"w");
		fwrite($fifo, "quit");
		fclose($fifo);
		usleep(500000);
		exec("sudo -n /bin/systemctl stop pikrellcam > /dev/null 2>&1");
		}
	}
?>
