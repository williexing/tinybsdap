<script language=javascript>
var http_request 	= false;
var update_div	 	= '';				// Important to define this w/ global scope
var httpURL			= '';
var handler_global	= '';

function makeRequest_modified_div(URL, anydiv) 
{	
    http_request 	= false;
    update_div		= anydiv;
//    httpURL			= url;

    if (window.XMLHttpRequest) { // Mozilla, Safari,...
        http_request = new XMLHttpRequest();
        if (http_request.overrideMimeType) {
            http_request.overrideMimeType('text/xml');
            // See note below about this line
        }
    } else if (window.ActiveXObject) { // IE
        try {
            http_request = new ActiveXObject("Msxml2.XMLHTTP");
        } catch (e) {
            try {
                http_request = new ActiveXObject("Microsoft.XMLHTTP");
            } catch (e) {}
        }
    }

    if (!http_request) {
        alert('Giving up :( Cannot create an XMLHTTP instance');
        return false;
    }

    http_request.onreadystatechange = function() {handler_func_modified_div();} ;
    http_request.open('GET', URL, true);
    http_request.send(null);
}

function showStatus()
{
	document.getElementById(update_div).innerHTML="<img width=40 src=/ebaydev/progress.gif alt=waitplease>";
	document.all["divpage"].style.display = "block";
}

function replaceHTML_modified_div() 
{
    if (http_request.readyState == 4) 
    {
        if (http_request.status == 200) 
        {
//		alert(http_request.responseText);
		var elementToChange	= document.getElementById('modified_div');
		    elementToChange.innerHTML = '';
		    elementToChange.innerHTML = http_request.responseText;
//		var newOutput		= document.createTextNode(http_request.responseText);
//		elementToChange.appendChild(newOutput);
//		elementToChange.innerHTML=http_request.responseText;
		} 
        else {
            alert('There was a problem with the request.\n' + http_request.statusText + '\n' + URL);
        }
    }
}



function makeRequest(URL, anydiv) 
{	
    http_request 	= false;
    update_div		= anydiv;
//    httpURL			= URL; alert ($httpURL);

    if (window.XMLHttpRequest) { // Mozilla, Safari,...
        http_request = new XMLHttpRequest();
        if (http_request.overrideMimeType) {
            http_request.overrideMimeType('text/xml');
            // See note below about this line
        }
    } else if (window.ActiveXObject) { // IE
        try {
            http_request = new ActiveXObject("Msxml2.XMLHTTP");
        } catch (e) {
            try {
                http_request = new ActiveXObject("Microsoft.XMLHTTP");
            } catch (e) {}
        }
    }

    if (!http_request) {
        alert('Giving up :( Cannot create an XMLHTTP instance');
        return false;
    }

    http_request.onreadystatechange = function() {replaceHTML2(update_div);} ;
    http_request.open('GET', URL, true);
    http_request.send(null);
}

function replaceHTML2(update_div) 
{
//alert (update_div + ' | state=' + http_request.readyState);
    if (http_request.readyState == 4) 
    {
        if (http_request.status == 200) 
        {
//		alert(http_request.responseText);
	    	document.getElementById(update_div).innerHTML=http_request.responseText;
//		document.all["divpage"].style.display = "none";
//		alert ("done loading");
        } 
        else 
        	{
            alert('There was a problem with the request.' + '\n' + http_request.statusText);
        }
    }
}


function UpdateInputBox() 
{
    if (http_request.readyState == 4) 
    {
        if (http_request.status == 200) 
        {
//			alert(http_request.responseText);
			var elementToChange	= document.getElementById('%div_name%');
				elementToChange.value = '';
				elementToChange.value = http_request.responseText;
		} 
        else {
            alert('There was a problem with the request.\n' + http_request.statusText + '\n' + httpURL);
        }
    }
}
</script>
