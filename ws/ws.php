<?php
session_start();
if ($_SESSION[extension]) {
   if ($_REQUEST[action] == 'callnow') {
	  $ticketid = $_REQUEST[requestId];
	  $extension = $_SESSION[extension];
	  $destination = $_REQUEST[destination];
	  
	  if ($destination) {
		 $ticketid = $_REQUEST[ticketid];
		 $str = "Channel:SIP/$extension
Callerid:$destination <$destination>
Context:whmcs_out
Extension:$destination
Priority:1
Set:__ticketid=$ticketid
";

		 $file = time();
		 
		 file_put_contents("/var/spool/asterisk/outgoing/$file.call", $str);
		 
		 echo "<script>window.close()</script>";
		 exit(0);
	  }
	  
	  echo "<form >";
	  echo "Ticketid: <input type-text name=ticketid value='$ticketid' readonly /><br>\n";
	  echo "Extension: <input type-text name=extension value='$extension' /><br>\n";
	  echo "Destination: <input type-text name=destination value='$destination' /><br>\n";
	  echo "<input type=hidden name=action value='callnow' />\n";
	  echo "<input type=submit name=submit value='callnow' />\n";
	  echo "</form>";
	  exit;
   }
}
?>
<html>
   <head>
      <script type="text/javascript" src="/admin/assets/js/jquery-3.1.1.min.js"></script> 
      <script type = "text/javascript">
         var extension = "<?php echo $_SESSION[extension];?>"
		 if (!extension) {
			window.location.href='/ws/login.php';
		 }
         function startws() {
            
            if ("WebSocket" in window) {
               var ws = new WebSocket("ws://jaypbx.cfbtel.com:8080");
				
               ws.onopen = function() {
                  
                  var sent_msg = '{"action":"login","agent":"' + extension + '","domain_name":"jaypbx.cfbtel.com"}';
                  // Web Socket is connected, send data using send()
                  ws.send(sent_msg);
                  console.log("Message is sent: " + sent_msg);
               };
				
               ws.onmessage = function (evt) { 
                  var received_msg = evt.data;
                  console.log("Message is received: " + received_msg);
                  
                  var event = obj =JSON.parse(received_msg);
                  if (event.to) {
                     //alert(event.agent + event.ticketid);
                     
                     window.open("http://help.cfbtel.com/WorkOrder.do?woMode=viewWO&fromListView=true&woID=" + event.ticketid, '', '');
					 return true;
                  }
                  if (event.action == 'login') {                    
                    $('#console').html('<font color=green>Login Successfully, Waiting new calls for extension=' + extension + '...</font>');
					return true;
                  }
               };
				
            ws.onerror = function(error) {
                $('#console').html("<font color=red> Connection Error!" + error.message + "</font>");
              };
               ws.onclose = function() { 
                  
                  // websocket is closed.
                  $('#console').html("<font color=red>Connection is closed...</font>"); 
               };
            } else {
              
               // The browser doesn't support WebSocket
                $('#console').html("<font color=red>WebSocket NOT supported by your Browser!</font>");
            }
         }
        function stop() {
            s = confirm("confirm to leave?");
            if (s) {
                window.location.href='login.php?action=LogOut';
            }
           
        }
      startws();
      </script>
		
   </head>
   
   <body>
    <a href='#' onclick='stop();return false;'>Logout</a><br>
     <center>
      <div id = "console" >
         
      </div>
    </center>
   </body>
</html>