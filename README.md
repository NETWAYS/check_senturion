check_senturion
===============

Sensatronic Senturion is a Ethernet Device to monitor temperature, humidity, airflow and light level.

The Sensatronic Senturion is a 1U sized monitor is a turnkey solution with fully integrated sensors (temperature, humidity, airflow and light level); a built in web interface; SNMP support; and onboard email, SMS, local audible and local visual alerting.


### Requirements

* Perl libraries: `Net::SNMP`
    
### Usage

    check_senturion.pl -H host [ -C community ] [ -t type | -p probeid ] -w warn -c crit 
    
    Options:
     -H, --host STRING or IPADDRESS
     -C, --community STRING
     -t, --type STRING (temperature,humidity,light,airflow)
     -p, --probe INTEGER (1,2,3,...)
     -w, --warning INTEGER
     -c, --critical INTEGER
     -V, --version
     -h, --help
        Display this screen.
