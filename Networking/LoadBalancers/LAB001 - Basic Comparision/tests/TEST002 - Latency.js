// HOW TO:
// 1. Make sure you have k6 installed
// 2. Run 'k6 run .\tests\TEST002 - Latency.js'

import http from 'k6/http';
import { sleep } from 'k6';

export let options = {
  vus: 10,          // Number of virtual users
  duration: '30s',  // Test duration
};

export default function () {
  // NOTE: Specify the target URL
  // You can put here publicly available IP address or DNS for VM, Load Balancer, Traffic Manger, Application Gateway or Front Door
  let url = 'http://afd-defaultendpoint-fhdsesembfdageey.z03.azurefd.net/_health'

  let response = http.get(url);
  console.log(`Response time for ${url}: ${response.timings.duration} ms`);

  sleep(1);
}