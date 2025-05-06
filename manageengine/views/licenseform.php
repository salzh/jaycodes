
<ul class="nav nav-tabs" role="tablist">
	<li role="presentation" data-name="general" class="change-tab">
		<a href="?display=manageengine#general" aria-controls="general" role="tab2" data-toggle="tab2">
			<?php echo _("General Settings")?>
		</a>
	</li>
	<li role="presentation" data-name="recording" class="change-tab">
		<a href="?display=manageengine#recording" aria-controls="recording" role="tab2" data-toggle="tab2">
			<?php echo _("Recording Settings")?>
		</a>
	</li>
	<li role="presentation" data-name="license" class="active">
		<a href="?display=manageengine&showlicense=true" aria-controls="license" role="tab2" data-toggle="tab2">
			<?php echo _("Show License")?>
		</a>
	</li>
</ul>
<input type="hidden" name="action" value="updatelicense">

<div class="tab-content display">
	<div role="tabpanel" id="general" class="tab-pane active">
		

		<div class="element-container">
				<div class="row">
						<div class="form-group">
								<div class="col-md-3">
										<label class="control-label" for="license_key"><?php echo _("license key") ?></label>
								</div>
								<div class="col-md-9">
										<input type="text" class="form-control" id="license_key" name="license_key" value="<?php echo $licensekey ?>">
								</div>
						</div>
				</div>
				<div class="row">
						<div class="col-md-12">
								<span id="license_key-help" class="help-block2 fpbx-help-block2"><?php echo $description; ?></span>
						</div>
				</div>
		</div>
		
		<div class="element-container">
				<div class="row">
						<div class="form-group">
								<div class="col-md-3">
										<label class="control-label" for="license_status"><?php echo _("License Status") ?></label>
								</div>
								<div class="col-md-9">
										<?php echo $licensestatus;?>
								</div>
						</div>
				</div>
				<div class="row">
						<div class="col-md-12">
								<span id="license_key-help" class="help-block2 fpbx-help-block2"><?php echo $description; ?></span>
						</div>
				</div>
		</div>
		
		<div class="element-container">
				<div class="row">
						<div class="form-group">
								<div class="col-md-3">
										<label class="control-label" for="author"><?php echo _("Author") ?></label>
								</div>
								<div class="col-md-9">
										<?php echo 'CFBTEL';?>
								</div>
						</div>
				</div>
				<div class="row">
						<div class="col-md-12">
								<span id="license_key-help" class="help-block2 fpbx-help-block2"><?php echo $description; ?></span>
						</div>
				</div>
		</div>
		<div class="element-container">
				<div class="row">
						<div class="form-group">
								<div class="col-md-3">
										<label class="control-label" for="author"><?php echo _("") ?></label>
								</div>
								<div class="col-md-9">
										<?php echo 'For Support Send us an email to help@cfbtel.com';?>
								</div>
						</div>
				</div>
				<div class="row">
						<div class="col-md-12">
								<span id="license_key-help" class="help-block2 fpbx-help-block2"><?php echo $description; ?></span>
						</div>
				</div>
		</div>
		
	</div>
</div>

