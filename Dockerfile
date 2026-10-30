FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /Frais-Core-API
COPY ["Frais-Core-API.csproj", "."]
RUN dotnet restore "Frais-Core-API.csproj"
COPY . .
RUN dotnet build "Frais-Core-API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Frais-Core-API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Frais-Core-API.dll"]
