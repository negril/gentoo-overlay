<?php
/* Autoloader for inwx-domrobot and its dependencies */

if (!class_exists('Fedora\\Autoloader\\Autoload', false)) {
    require_once '/usr/share/php/Fedora/Autoloader/autoload.php';
}

\Fedora\Autoloader\Autoload::addPsr4('Monolog\\', __DIR__."/src/Monolog");

// Dependencies, there are more in the real autoloader.
\Fedora\Autoloader\Dependencies::required(array(
  '/usr/share/php/Psr/Log/autoload.php'
));

