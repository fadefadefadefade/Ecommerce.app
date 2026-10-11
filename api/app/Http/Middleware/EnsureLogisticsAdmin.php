<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Logistics panel in the app is for `logistics` and `sorting_center` accounts (e.g. logistics@alvy.trade). */
class EnsureLogisticsAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! in_array($request->user()?->role, ['logistics', 'sorting_center'], true)) {
            return response()->json([
                'message' => 'You do not have permission to access the logistics panel.',
            ], 403);
        }

        return $next($request);
    }
}
