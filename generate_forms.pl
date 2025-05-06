open(IN,"/etc/aws.cfg");
while (<IN>) {
	chomp($_);
	($key,$val) = split(/\s*\=\s*/,$_,2);

	next unless $key && $val;
	($des = $key) =~ s/_/ /;
	if ($key ne 'tts_voiceid') {
		
	print <<HTML;
	
<!--Default $des header-->
<div class="element-container">
	<div class="row">
		<div class="form-group">
			<div class="col-md-3">
				<label class="control-label" for="$key"><?php echo _("$des") ?></label>
				<i class="fa fa-question-circle fpbx-help-icon" data-for="$key"></i>
			</div>
			<div class="col-md-9">
				<input type="text" class="form-control" id="$key" name="$key" value="<?php  echo \$config['$key']; ?>">
			</div>
		</div>
	</div>
	<div class="row">
		<div class="col-md-12">
			<span id="$key-help" class="help-block fpbx-help-block"><?php echo _("input $des")?></span>
		</div>
	</div>
</div>

HTML
} else {
	$voiceid_string = 'Aditi,Amy,Astrid,Bianca,Brian,Camila,Carla,Carmen,Celine,Chantal,Conchita,Cristiano,Dora,Emma,Enrique,Ewa,Filiz,Geraint,Giorgio,Gwyneth,Hans,Ines,Ivy,Jacek,Jan,Joanna,Joey,Justin,Karl,Kendra,Kimberly,Lea,Liv,Lotte,Lucia,Lupe,Mads,Maja,Marlene,Mathieu,Matthew,Maxim,Mia,Miguel,Mizuki,Naja,Nicole,Penelope,Raveena,Ricardo,Ruben,Russell,Salli,Seoyeon,Takumi,Tatyana,Vicki,Vitoria,Zeina,Zhiyu';
	
	for (split ',', $voiceid_string) {
		print "				'$_' => '$_',\n";
	}
print <<TTS;
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="$key"><?php echo _("$des") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="$key"></i>
                        </div>
                        <div class="col-md-9">
                                <select class="form-control" id="$key" name="$key">
                                        <?php echo \$voiceid_opts ?>
                                </select>
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="$key-help" class="help-block fpbx-help-block"><?php echo _("$des")?></span>
                </div>
        </div>
</div>
TTS
}

}
close(IN);
               
               

	