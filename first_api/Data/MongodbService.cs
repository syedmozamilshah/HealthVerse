using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection.Emit;
using System.Threading.Tasks;
using MongoDB.Driver;

// M-1 USED IN AUTH CONTROLLER FOR DB CONNECTION
// M-5 USED IN PRESCRIPTION CONTROLLER FOR DB CONNECTION
namespace first_api.Data
{
    public class MongodbService
    {
        private readonly IConfiguration _configuration;
        private readonly IMongoDatabase? _database;
        public MongodbService(IConfiguration configuration)
        {
            _configuration = configuration;
            var connectionString = _configuration.GetConnectionString("DbConnection");
            var mongoUrl = MongoUrl.Create(connectionString);
            var mongoClient = new MongoClient(mongoUrl);
            _database = mongoClient.GetDatabase(mongoUrl.DatabaseName);
         }

        public IMongoDatabase? Database => _database;
    }
}