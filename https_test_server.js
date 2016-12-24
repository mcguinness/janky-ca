'use strict';

const fs = require('fs');
const https = require('https');
const yargs = require('yargs');

/**
 * Arguments
 */

require('dotenv').config()

var argv = yargs
  .usage('\nHTTPS Test Server\n\n' +
      'Usage: $0 --port {port} --cert {cert} --key {key} --ca {ca}', {
    port: {
      description: 'HTTPS Server Listener Port',
      required: true,
      alias: 'p',
      default: 44303
    },
    cert: {
      description: 'TLS Public Key',
      required: true,
    },
    key: {
      description: 'TLS Private Key',
      required: true,
    },
    ca: {
      description: 'TLS Certificate Authority Trust Root',
      required: true,
      default: process.env.CERT_AUTHORITY_HOME + '/certs/root_ca.pem'
    },
    mutual: {
      description: 'Require Mutual-TLS (Client Certificate)',
      required: true,
      type: 'boolean',
      default: false
    }
  })
  .example('\t$0 --cert "' + process.env.CERT_AUTHORITY_HOME + '/certs/{dnshost}.pem" --key "' + process.env.CERT_AUTHORITY_HOME + '/certs/{dnshost}.pem"', '')
  .check(function(argv, aliases) {
    if (!fs.existsSync(argv.cert)) {
      return 'TLS Certificate "' + argv.cert + '" is not a valid file path';
    }

    if (!fs.existsSync(argv.key)) {
      return 'TLS Private Key "' + argv.key + '" is not a valid file path';
    }

    if (!fs.existsSync(argv.ca)) {
      return 'TLS Certificate Authority Trust Root "' + argv.ca + '" is not a valid file path';
    }
    return true;
  })
  .argv;

const options = {
  cert: fs.readFileSync(argv.cert),
  key: fs.readFileSync(argv.key),
  ca: fs.readFileSync(argv.ca),
  requestCert: true,
  rejectUnauthorized: argv.mutual
};

console.log('Starting HTTPS Test Server...');
https.createServer(options, function (req, res) {
  console.log(new Date() + ' ' + req.connection.remoteAddress + ' ' + req.method + ' ' + req.url);
  if (req.client.authorized) {
    res.writeHead(200);
    res.end('<!doctype html><html><head><title>HTTPS Test</title></head><body><pre>' +
      JSON.stringify(req.socket.getPeerCertificate(), null, '\t') + '</pre></body></html>');
  } else {
    res.writeHead(401);
    res.end('<!doctype html><html><head><title>HTTPS Test</title></head><body><h1>No Client Certificate</h1></body></html>');
  }
}).listen(argv.port);

console.log('\thttps://0.0.0.0:' + argv.port);
console.log('\thttps://127.0.0.1:' + argv.port);
console.log('Hit CTRL-C to stop the server');


