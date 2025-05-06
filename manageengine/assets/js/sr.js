
$(document).ready(function(){
$(document).on('change', "[id^='recordingtoggle']",function(){
	var fmstate = "";
	var exten = $(this).data('for');
	if($(this).val() == "CHECKED"){
		fmstate = "disable";
	}else{
		fmstate = "enable";
	}
	$.get("ajax.php?module=manageengine&command=togglerecording&ext="+exten+"&state="+fmstate, function(data, status){
		if(data.toggle == 'received'){
			if(data.return){
				fpbxToast('Split Recording '+fmstate+'d',exten,'success');
			}else{
				fpbxToast(_('We received and sent your request but something failed'),exten,'warning');
			}
		}else{
			fpbxToast(_('Request not received'),_('Error'),'error');
		}
	});
	});
});


