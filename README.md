TerraMod
========

TerraMod is a framework for home automation.  This is a response to the prevalence of DIY home automation projects that are effective but lack intercommunication or user interfaces.  Terramod creates a simple API home automation projects can report events to and a highly extensible applicaion environment.  Terramod provides applications with many optional features including:

  * a management and settings page integrated into the menus
  * a main dashboard integrated into the menus
  * a tile on the main landing page
  * the ability to route any url to any method
  * sensor callbacks defined by regular expressions
  * scheduled tasks via cron

The applcation framework is extensible to encourage hobbyists to integrate their projects.  A standard set of documented hardware modules and applications is within the goal of the project as well.

Current State
-------------

During early development TerraMod is going through rapid prototying.  The third and final iteration of the framework is currently in development and is going to incorperate the following improvements:

   * Migrating to an ORM
   * Infering method refrences from strings in routes
   * Automated gem installation on app installation
   * Framework provided job support via cron
   * Apache deployment
   * User accounts and permissions
   * App upgrading process
   * Framework upgrading process
   * Formalize Nexus API, add security, move into framework
   * Finish Nexus setup features

Once the framework is no longer changing in large ways focus will shift to the development of hardware components and applications.

Goals
-----

### Nexus modules ###
  - [x] Motion sensor
  - [x] Entrance sensor
  - [ ] IR beam
  - [ ] Light sensor
  - [ ] Thermometer
  - [ ] Webcam / Mic
  - [ ] Speakers
  - [ ] Outlet
  - [ ] Electric strike
  - [ ] Blinds control
  - [ ] Wall control panel
  - [ ] Appliance interfacing
  - [ ] Thermostat

### Applications ###

  - [ ] Intelligent LIFX control ([GreenLights](https://github.com/Jkolber/greenlights) in development)
  - [ ] Audio Routing
  - [ ] Natural Langauge Processing

Nexus
-----

Nexus is a web application for Raspberry Pi that provides an API for attached hardware modules.  A full TerraMod installation will likely include a few Nexus devices across a home.  Nexus is being developed [here](https://github.com/hkparker/Nexus/).

Demo
----

Demo site is offline right now.

License
-------

This project is licensed under the MIT license, please see LICENSE.md for more information.
