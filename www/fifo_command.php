<?php
	require_once(dirname(__FILE__) . '/config.php');
	require_once(dirname(__FILE__) . '/security.php');
?>
<?php
	// The web page sends commands with XMLHttpRequest PUT.  Requiring PUT
	// means another web site cannot send one without a CORS preflight.
	pkc_require_method(array("PUT", "POST"));
	pkc_require_same_origin();

	// Only the commands the web page sends are accepted.  Commands that
	// run shell commands ("@..." and the at/motion command setters) and
	// anything with shell or path characters are rejected.
	$allowed = array("display", "motion", "motion_enable", "preset",
			"pan", "tilt", "servo", "record", "still", "pause", "loop",
			"tl_start", "tl_end", "tl_hold", "tl_show_status",
			"audio", "upgrade", "reboot", "halt");

	$cmd = isset($_GET["cmd"]) ? $_GET["cmd"] : "";
	$word = explode(" ", $cmd)[0];

	if (   strlen($cmd) > 128
	    || !preg_match('/^[A-Za-z0-9_.<> -]+$/', $cmd)
	    || !in_array($word, $allowed, true)
	   )
		{
		http_response_code(400);
		echo "Command not allowed";
		exit(0);
		}

	$fifo = fopen(FIFO_FILE,"w");
	fwrite($fifo, $cmd);
	fclose($fifo);
?>
