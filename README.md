# SIRIC - Sistema de Información y Rastreo de Incidentes Carabobo 

API RESTful, servicios en tiempo real y arquitectura backend para el registro, geolocalización y despacho de incidentes naturales y antrópicos, desarrollada para optimizar la capacidad de respuesta operativa en el Estado Carabobo.

---

##  Arquitectura del Sistema

```mermaid
graph TD
    Client[Aplicación Móvil Flutter / Clientes] -->|HTTP / REST API| API[Express.js / Node.js Backend]
    Client -->|WebSockets / Real-Time| WS[Event Broker]
    API -->|Consultas SQL / Optimización| DB[(Base de Datos Relacional MySQL)]
    API -->|Proxy Inverso / SSL| Nginx[Servidor Linux VPS / Nginx]
    Nginx --> OS[Ubuntu Server]
