@echo off
echo Starting HealthVerse Services...

:: 1. first_api
echo Starting first_api (.NET API)...
start "first_api" cmd /k "cd /d %~dp0first_api && dotnet run"

:: 2. BlazorUI
echo Starting BlazorUI...
start "BlazorUI" cmd /k "cd /d %~dp0BlazorUI && dotnet run"

:: 3. AdminDashboard
echo Starting AdminDashboard...
start "AdminDashboard" cmd /k "cd /d %~dp0AdminDashboard && dotnet run"

:: 4. HealthVerse-agent_with_mcp
echo Starting HealthVerse-agent_with_mcp (Python)...
start "Agent with MCP" cmd /k "cd /d %~dp0HealthVerse-agent_with_mcp && uvicorn app.main:app --host 0.0.0.0 --port 8000"

:: 5. HealthVerse-doctor-agents
echo Starting HealthVerse-doctor-agents (Python)...
start "Doctor Agents" cmd /k "cd /d %~dp0HealthVerse-doctor-agents && python main.py"

:: 6. fyp (Flutter app)
echo Starting Flutter App...
start "Flutter App (Windows)" cmd /k "cd /d %~dp0fyp && flutter run -d windows"

echo All services are starting up! Please check the newly opened terminal windows.
pause
