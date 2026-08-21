FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file (safe for monorepo root build context)
COPY ["BlazorUI/BlazorUI.csproj", "./"]
RUN dotnet restore "./BlazorUI.csproj"

# Copy remaining sources
COPY ["BlazorUI/", "./"]

# Publish
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Copy published output
COPY --from=build /app/publish .

EXPOSE 80

# Bind to Render's provided PORT at runtime
CMD ["bash", "-lc", "dotnet BlazorUI.dll --urls http://0.0.0.0:$PORT"]
