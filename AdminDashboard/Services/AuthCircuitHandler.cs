using Microsoft.AspNetCore.Components.Server.Circuits;

namespace AdminDashboard.Services
{
    public class AuthCircuitHandler : CircuitHandler
    {
        private readonly AuthService _authService;

        public AuthCircuitHandler(AuthService authService)
        {
            _authService = authService;
        }

        // When the circuit is disconnected (tab closed or connection lost), clear auth state
        public override async Task OnCircuitClosedAsync(Circuit circuit, CancellationToken cancellationToken)
        {
            _authService.Logout();
            await base.OnCircuitClosedAsync(circuit, cancellationToken);
        }
    }
}
