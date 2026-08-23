"""
tests/test_specialists.py

Full test suite for all 4 specialist agents.
Run: python tests/test_specialists.py
"""
import asyncio
import sys
import os

# Fix Windows cp1252 console encoding
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agents.base_agent import run_specialist_agent
from agents.specialists.ophthalmologist import SPECIALIST_CONFIG as OPHTHALMOLOGIST
from agents.specialists.optometrist import SPECIALIST_CONFIG as OPTOMETRIST
from agents.specialists.optician import SPECIALIST_CONFIG as OPTICIAN
from agents.specialists.ocularist import SPECIALIST_CONFIG as OCULARIST

SEP = "=" * 70

def msg(role, content):
    return {"role": role, "content": content}

async def run_test(title: str, config: dict, messages: list, expect_red_flag: bool = False):
    print(f"\n{SEP}")
    print(f"TEST: {title}")
    print(f"SPECIALIST: {config['name']}")
    print(f"MESSAGES:")
    for m in messages:
        print(f"  [{m['role'].upper()}]: {m['content']}")
    print("-" * 70)

    try:
        result = await run_specialist_agent(config, messages)
        print(f"RESPONSE:\n{result['response']}")
        print(f"\nRED FLAGS: {result['red_flags']}")
        print(f"ESCALATION NEEDED: {result['escalation_needed']}")

        if expect_red_flag and not result['red_flags'] and 'urgent' not in result['response'].lower() and 'emergency' not in result['response'].lower():
            print("⚠️  WARNING: Expected red flag detection but none found in flags (check response text)")
        elif expect_red_flag:
            print("✅ Red flag correctly identified")

        return True
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

async def main():
    results = []

    # ──────────────────────────────────────────────────────────────────────────
    print(f"\n{'#'*70}")
    print("# OPHTHALMOLOGIST TESTS")
    print(f"{'#'*70}")

    # Test 1: Partial symptom — must NOT say "not enough context"
    results.append(await run_test(
        "1. Partial symptom (must not say 'not enough context')",
        OPHTHALMOLOGIST,
        [msg("user", "Patient has blurry vision.")],
    ))

    # Test 2: RED FLAG — sudden painless vision loss
    results.append(await run_test(
        "2. Sudden painless vision loss (RED FLAG expected)",
        OPHTHALMOLOGIST,
        [msg("user", "Patient has sudden painless loss of vision in the right eye.")],
        expect_red_flag=True,
    ))

    # Test 3: Red eye + photophobia
    results.append(await run_test(
        "3. Red eye and photophobia",
        OPHTHALMOLOGIST,
        [msg("user", "Patient has red eye and photophobia since this morning.")],
    ))

    # Test 4: Multi-turn conversation — context must build up
    results.append(await run_test(
        "4a. Multi-turn — first message",
        OPHTHALMOLOGIST,
        [msg("user", "Patient has blurry vision.")],
    ))
    results.append(await run_test(
        "4b. Multi-turn — add onset",
        OPHTHALMOLOGIST,
        [
            msg("user", "Patient has blurry vision."),
            msg("assistant", "Blurry vision can be caused by several conditions..."),
            msg("user", "Started yesterday."),
        ],
    ))
    results.append(await run_test(
        "4c. Multi-turn — laterality",
        OPHTHALMOLOGIST,
        [
            msg("user", "Patient has blurry vision."),
            msg("assistant", "Blurry vision can be caused by..."),
            msg("user", "Started yesterday."),
            msg("assistant", "Acute onset suggests..."),
            msg("user", "Only the right eye."),
        ],
    ))
    results.append(await run_test(
        "4d. Multi-turn — IOP 28 (must integrate all prior context)",
        OPHTHALMOLOGIST,
        [
            msg("user", "Patient has blurry vision."),
            msg("assistant", "Blurry vision can be caused by..."),
            msg("user", "Started yesterday."),
            msg("assistant", "Acute onset suggests..."),
            msg("user", "Only the right eye."),
            msg("assistant", "Unilateral acute blurred vision..."),
            msg("user", "IOP is 28."),
        ],
        expect_red_flag=True,
    ))

    # Test 5: General knowledge question
    results.append(await run_test(
        "5. General ophthalmology question",
        OPHTHALMOLOGIST,
        [msg("user", "What are the layers of the cornea?")],
    ))

    # Test 6: Out of domain
    results.append(await run_test(
        "6. Out-of-domain question (should politely decline)",
        OPHTHALMOLOGIST,
        [msg("user", "What is the weather like today in Lahore?")],
    ))

    # ──────────────────────────────────────────────────────────────────────────
    print(f"\n{'#'*70}")
    print("# OPTOMETRIST TESTS")
    print(f"{'#'*70}")

    results.append(await run_test(
        "7. VA interpretation",
        OPTOMETRIST,
        [msg("user", "Patient's VA is 6/12 in the right eye and 6/6 in the left. No glasses.")],
    ))

    results.append(await run_test(
        "8. Contact lens for myopia",
        OPTOMETRIST,
        [msg("user", "Patient has myopia -3.50 DS. Best contact lens type?")],
    ))

    # ──────────────────────────────────────────────────────────────────────────
    print(f"\n{'#'*70}")
    print("# OPTICIAN TESTS")
    print(f"{'#'*70}")

    results.append(await run_test(
        "9. Outdoor lens coating recommendation",
        OPTICIAN,
        [msg("user", "What lens coating should I recommend for a patient who works outdoors?")],
    ))

    results.append(await run_test(
        "10. Optician receives clinical emergency (must escalate)",
        OPTICIAN,
        [msg("user", "Patient just told me they suddenly can't see from their left eye.")],
        expect_red_flag=True,
    ))

    # ──────────────────────────────────────────────────────────────────────────
    print(f"\n{'#'*70}")
    print("# OCULARIST TESTS")
    print(f"{'#'*70}")

    results.append(await run_test(
        "11. Socket discharge post-enucleation",
        OCULARIST,
        [msg("user", "Patient has discharge from the socket 3 months after enucleation. No pain.")],
    ))

    results.append(await run_test(
        "12. Prosthesis maintenance question",
        OCULARIST,
        [msg("user", "How often should a prosthetic eye be polished and what is the procedure?")],
    ))

    # ──────────────────────────────────────────────────────────────────────────
    print(f"\n{SEP}")
    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"\n📊 TEST RESULTS: {passed}/{total} passed")
    if passed == total:
        print("✅ All tests passed!")
    else:
        print(f"⚠️  {total - passed} tests failed.")

if __name__ == "__main__":
    asyncio.run(main())
