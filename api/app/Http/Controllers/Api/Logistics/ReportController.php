<?php

namespace App\Http\Controllers\Api\Logistics;

use App\Http\Controllers\Controller;
use App\Models\Parcel;
use App\Models\ParcelDelivery;
use App\Models\Rider;
use Carbon\Carbon;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function index(Request $request)
    {
        $from = $request->from ? Carbon::parse($request->from)           : now()->subDays(30)->startOfDay();
        $to   = $request->to   ? Carbon::parse($request->to)->endOfDay() : now()->endOfDay();

        $summary = [
            'total_parcels'     => Parcel::whereBetween('created_at', [$from, $to])->count(),
            'delivered'         => ParcelDelivery::where('status', 'delivered')
                                      ->whereBetween('delivered_at', [$from, $to])->count(),
            'failed'            => ParcelDelivery::where('status', 'failed')
                                      ->whereBetween('updated_at', [$from, $to])->count(),
            'new_rider_signups' => Rider::whereBetween('created_at', [$from, $to])->count(),
        ];

        $deliveries = ParcelDelivery::with(['parcel:id,tracking_number', 'rider:id,full_name', 'area:id,name'])
            ->whereBetween('created_at', [$from, $to])
            ->latest()
            ->paginate(20);

        return response()->json([
            'from'       => $from->toDateString(),
            'to'         => $to->toDateString(),
            'summary'    => $summary,
            'deliveries' => $deliveries,
        ]);
    }

    /** Same columns as the web's CSV export; returned as text so the app can save it. */
    public function export(Request $request)
    {
        $from = $request->from ? Carbon::parse($request->from)           : now()->subDays(30)->startOfDay();
        $to   = $request->to   ? Carbon::parse($request->to)->endOfDay() : now()->endOfDay();

        $deliveries = ParcelDelivery::with(['parcel', 'rider', 'area'])
            ->whereBetween('created_at', [$from, $to])
            ->get();

        $handle = fopen('php://temp', 'r+');
        fputcsv($handle, ['Tracking #', 'Rider', 'Area', 'Status', 'Assigned At', 'Delivered At']);

        foreach ($deliveries as $d) {
            fputcsv($handle, [
                $d->parcel->tracking_number ?? '-',
                $d->rider->full_name        ?? '-',
                $d->area->name              ?? '-',
                $d->status,
                $d->created_at,
                $d->delivered_at,
            ]);
        }

        rewind($handle);
        $csv = stream_get_contents($handle);
        fclose($handle);

        return response()->json([
            'filename' => 'delivery-report-' . now()->format('Y-m-d') . '.csv',
            'rows'     => $deliveries->count(),
            'csv'      => $csv,
        ]);
    }
}
