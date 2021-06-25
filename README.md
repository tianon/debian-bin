# debian-bin

A collection of small(ish) Debian-focused utiltiies to help automate/accelerate various tasks around Debian packaging and building.

Many will utilize Docker, but many are also reasonably standalone (like `extract-origtargz`, which I've been using successfully for years now).

This repository supercedes https://gist.github.com/tianon/a0080cbca558e4b907fe with hopefully growing success.

## utilities

- convert source dir to source package  
  https://github.com/docker-library/oi-janky-groovy/blob/58058916f724b282296550d007765d15cecf3f2f/tianon/docker-deb/source-pipeline.groovy#L49-L54  
  `dsc-from-source`

- given .dsc, create new .dsc with version suffix and new suite  
  https://github.com/docker-library/oi-janky-groovy/blob/58058916f724b282296550d007765d15cecf3f2f/tianon/docker-deb/source-pipeline.groovy#L65-L76  
  `dsc-new-suite`

- given docker image, create sbuild tarball  
  https://github.com/docker-library/oi-janky-groovy/blob/58058916f724b282296550d007765d15cecf3f2f/tianon/docker-deb/arch-pipeline.groovy#L147-L158  
  `docker-image-to-sbuild-schroot`

- given .dsc and sbuild tarball, sbuild  
  https://github.com/docker-library/oi-janky-groovy/blob/58058916f724b282296550d007765d15cecf3f2f/tianon/docker-deb/arch-pipeline.groovy#L186-L231  
  `docker-sbuild`
