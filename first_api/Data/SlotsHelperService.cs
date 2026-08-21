using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using first_api.Entities.DoctorModel;

// M-2 Used in profile
namespace first_api.Data
{
    public class SlotsHelperService
    {
        public List<Slot> GenerateSlots(DateTime start, DateTime end)
        {
            List<Slot> slots = new();
            DateTime current = start;

            while (current < end)
            {
                slots.Add(new Slot
                {
                    StartTime = current,
                    EndTime = current.AddMinutes(30),
                    IsBooked = false,
                    UserId = string.Empty
                });

                current = current.AddMinutes(30);
            }

            return slots;
        }

    }
}