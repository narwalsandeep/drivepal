## Core Gap Audit (API + App only)

Scope: focus only on `api/` and `app/` for Uber-like core flow. Admin dashboard is intentionally excluded.

### What is already strong
- Auth, OTP, rider/driver role handling, onboarding gates.
- Rider booking flow with map route, car type, scheduling, and payment method selection.
- Driver request acceptance flow and trip lifecycle actions.
- Stripe card setup + charging flow.
- Alerts, scheduled ride reminders, and driver earnings basics.

### What is missing or half-finished (core only)
- Push notification pipeline is still not implemented (polling-based behavior only).
- Fare model is still basic distance-per-km only.
- Reliability hardening and deeper e2e coverage can be improved.

## Priority Order (what to build first)

### Done (completed)
1. **Fix cancellation + refund contract end-to-end**
2. **Introduce live trip tracking contracts**
3. **Create rider active-trip experience**
4. **Make driver request feed truly live**
5. **Use `driver_arriving` as explicit lifecycle step**

### P2 (next focus)
6. **Add push notifications**
   - New request, cancellation, reassignment, trip started/completed reminders.
   - Keep polling as fallback, but push should be primary trigger.

7. **Upgrade fare model**
   - Move beyond only distance-per-km (base fare/time/waiting/surge if needed).
   - Keep estimate vs final fare behavior explicit.

8. **Strengthen reliability and ops**
   - Add stronger e2e paths for booking->payment->trip completion and cancel->refund.
   - Tighten production safeguards (security headers/rate limit/config hardening).

9. **Improve user trust UX**
   - Better empty/error states for network retries and delayed updates.
   - Keep rider/driver status wording fully aligned with backend truth.

## Recommended execution sequence
1) Push notifications -> 2) Fare model enhancements -> 3) Reliability hardening -> 4) UX trust polish.
