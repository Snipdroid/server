![API](https://img.shields.io/website?down_color=lightgrey&down_message=Offline&label=API&up_color=green&up_message=Online&url=http%3A%2F%2Fapptracker.sg.butanediol.me%2Fapp-info%2Fsearch)

## Host your instance

To run your own instance of AppTracker, you'll need:
- Docker and Docker Compose installed
- AWS S3-compatible storage (like Cloudflare R2)

### Environment Variables

Set the following environment variables or modify them in `docker-compose.yml`:

```env
LOG_LEVEL=debug
DATABASE_HOST=db
DATABASE_NAME=vapor_database
DATABASE_USERNAME=vapor_username
DATABASE_PASSWORD=vapor_password
JWT_SECRET=your_secret_here
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_ENDPOINT=your_s3_endpoint
```

### Running the Service

1. Build the Docker images:
```bash
docker compose build
```

2. Start the PostgreSQL database:
```bash
docker compose up db -d
```

3. Run database migrations:
```bash
docker compose run migrate
```

4. Start the application:
```bash
docker compose up app -d
```

The API will be available at `http://localhost:8080`.

### Managing the Database

- To revert migrations:
```bash
docker compose run revert
```

- To stop all services:
```bash
docker compose down
```
Add `-v` flag to also remove the database volume:
```bash
docker compose down -v
```