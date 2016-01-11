TerraMod
========

TerraMod is a framework for home automation.  This is a response to the prevalence of DIY home automation projects that are effective but lack intercommunication or user interfaces.  Terramod creates a simple API home automation projects can report events to and a highly extensible applicaion environment.  Terramod provides applications with many optional features including:

  * a management and settings page integrated into the menus
  * a main dashboard integrated into the menus
  * a tile on the main landing page
  * control over http routing
  * sensor callbacks defined by regular expressions
  * scheduled tasks

The applcation framework is extensible to encourage hobbyists to integrate their projects.  A standard set of documented hardware modules and applications is within the goal of the project as well.

Current State
-------------

Early implementations of TerraMod were effective but mostly proof of concepts.  The third and final implementation the framework has been started and will focus on the following improvements:

* Formalize frontend framework
* Hardware behaviors and locations defined in app
* App installation and upgrading via git
* Automated gem installation on app installation
* Framework provided job support
* Authentication, users, and permissions
* Formalize Nexus API, authenticate, move into framework

Once the framework is no longer changing in large ways focus will shift to the development of hardware components and applications.  Lead dev is on hiatus with other projects and work, progress is expected to resume summer 2016.

Goals
-----

### Nexus modules ###
- [x] Motion sensor
- [x] Entrance sensor
- [ ] IR beam
- [ ] Light sensor
- [ ] Thermometer
- [ ] Webcam
- [ ] Speakers
- [ ] Outlet with control and metrics
- [ ] Electric strike
- [ ] Blinds control
- [ ] Wall control panel
- [ ] Appliance interfacing
- [ ] Thermostat
- [ ] Fire alarm
- [ ] Audio inputs

### Applications ###

- [ ] Intelligent LIFX control ([GreenLights](https://github.com/Jkolber/greenlights) in development)
- [ ] Audio Routing

Nexus
-----

Nexus is a web application for Raspberry Pi that provides an API for attached hardware modules.  A full TerraMod installation will likely include a few Nexus devices across a home.  Nexus is being developed [here](https://github.com/hkparker/Nexus/).

Demo
----

Demo site is offline right now.

License
-------

This project is licensed under the MIT license, please see LICENSE.md for more information.
