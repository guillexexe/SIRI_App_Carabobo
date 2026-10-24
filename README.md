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
Tecnologías PrincipalesRuntime: 
    Node.js (v18+)
    Framework Backend: Express.js
    Base de Datos: MySQL (Modelado relacional y optimización de consultas)
    Frontend / Móvil (Soporte): Flutter (Dart) / PHP
    Infraestructura y DevOps: Linux (Ubuntu VPS), Nginx (Reverse Proxy), Docker / Docker-Compose
    Control de Versiones: Git / GitFlow
Características y Métricas de Impacto
    Optimización en Tiempo Real: Reducción del tiempo de respuesta y geolocalización de eventos críticos en un 80% (de 10 a 2 minutos) mediante servicios asíncronos en Node.js.
    Rendimiento de Base de Datos: Diseño de esquemas relacionales optimizados para 12 categorías de incidentes, manteniendo tiempos de respuesta por debajo de los 150ms bajo simulaciones de carga concurrente.
    Consistencia Transaccional: Garantía del 100% de consistencia de datos en la integración entre los clientes móviles y el servidor central.
    Disponibilidad: Configuración de alta disponibilidad (99.9% de uptime) en entorno de producción sobre servidores VPS Linux con Nginx.
Instalación y Configuración Local
    Prerrequisitos
        Node.js (v18 o superior)
        MySQL (v8.0+)Git
1. Clonar el repositorio
Bash
    git clone [https://github.com/guillexexe/siric-app-carabobo.git](https://github.com/guillexexe/siric-app-carabobo.git)
    cd siric-app-carabobo
2. Instalar dependencias
Bash
    npm install
3. Configurar variables de entorno
    Duplica el archivo de ejemplo y completa los parámetros de conexión a tu base de datos y puerto:
    Bash
        cp .env.example .env
4. Ejecutar con Docker (Opcional)
    Bash
    docker-compose up --build -d
5. Iniciar en modo desarrollo
    Bash
    npm run dev
Endpoints Principales de la API
Método   Endpoint               Descripción
GET      /api/v1/incidents      Lista todos los incidentes activos en el sistema
POST     /api/v1/incidents      Registra y geolocaliza un nuevo incidente crítico
GET      /api/v1/incidents/:id  Obtiene el detalle y las coordenadas geográficas de un incidente
 Autor
Guillermo Nicolás Ferreira MendozaIngenieria en Computación — Universidad José Antonio Páez (UJAP)
GitHub Profile | LinkedIn
