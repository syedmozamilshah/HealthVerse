FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# When building from a monorepo root, copy the project file from the first_api folder
# This makes the Dockerfile safe to use whether the build context is the repo root
# or the `first_api` directory.
COPY ["first_api/first_api.csproj", "./"]
RUN dotnet restore "./first_api.csproj"

# Copy the project files
COPY ["first_api/", "./"]

# Publish
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# Copy published output
COPY --from=build /app/publish .

EXPOSE 80

# Use Render's provided $PORT at runtime by executing via sh instead of bash -lc
CMD dotnet first_api.dll --urls http://0.0.0.0:$PORT
