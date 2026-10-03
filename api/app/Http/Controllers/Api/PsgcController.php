<?php

namespace App\Http\Controllers\Api;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class PsgcController extends Controller
{
    private const BASE = 'https://psgc.gitlab.io/api';
    private const TTL  = 60 * 24 * 7; // cache for 7 days (minutes)

    public function regions()
    {
        $data = Cache::remember('psgc_regions', self::TTL, function () {
            $response = Http::withOptions(['verify' => false])
                ->timeout(15)
                ->get(self::BASE . '/regions/');

            if (! $response->successful()) {
                // Fallback: hardcoded Philippine regions
                return [
                    ['code'=>'010000000','name'=>'Region I – Ilocos Region'],
                    ['code'=>'020000000','name'=>'Region II – Cagayan Valley'],
                    ['code'=>'030000000','name'=>'Region III – Central Luzon'],
                    ['code'=>'040000000','name'=>'Region IV-A – CALABARZON'],
                    ['code'=>'170000000','name'=>'Region IV-B – MIMAROPA'],
                    ['code'=>'050000000','name'=>'Region V – Bicol Region'],
                    ['code'=>'060000000','name'=>'Region VI – Western Visayas'],
                    ['code'=>'070000000','name'=>'Region VII – Central Visayas'],
                    ['code'=>'080000000','name'=>'Region VIII – Eastern Visayas'],
                    ['code'=>'090000000','name'=>'Region IX – Zamboanga Peninsula'],
                    ['code'=>'100000000','name'=>'Region X – Northern Mindanao'],
                    ['code'=>'110000000','name'=>'Region XI – Davao Region'],
                    ['code'=>'120000000','name'=>'Region XII – SOCCSKSARGEN'],
                    ['code'=>'130000000','name'=>'Region XIII – Caraga'],
                    ['code'=>'140000000','name'=>'CAR – Cordillera Administrative Region'],
                    ['code'=>'150000000','name'=>'BARMM – Bangsamoro'],
                    ['code'=>'990000000','name'=>'NCR – National Capital Region'],
                ];
            }

            return collect($response->json())
                ->sortBy('name')
                ->map(fn($r) => ['code' => $r['code'], 'name' => $r['name']])
                ->values()
                ->toArray();
        });

        return response()->json($data);
    }

    public function provincesByRegion(string $code)
    {
        $data = Cache::remember("psgc_prov_region_{$code}", self::TTL, function () use ($code) {
            $response = Http::withOptions(['verify' => false])
                ->timeout(15)
                ->get(self::BASE . "/regions/{$code}/provinces/");

            if (! $response->successful()) {
                return [];
            }

            return collect($response->json())
                ->sortBy('name')
                ->map(fn($p) => ['code' => $p['code'], 'name' => $p['name']])
                ->values()
                ->toArray();
        });

        return response()->json($data);
    }

    public function provinces()
    {
        $data = Cache::remember('psgc_provinces', self::TTL, function () {
            $response = Http::withOptions(['verify' => false])
                ->timeout(15)
                ->get(self::BASE . '/provinces/');

            if (! $response->successful()) {
                return $this->fallbackProvinces();
            }

            return collect($response->json())
                ->sortBy('name')
                ->map(fn($p) => ['code' => $p['code'], 'name' => $p['name']])
                ->values()
                ->toArray();
        });

        return response()->json($data);
    }

    public function municipalities(string $code)
    {
        $data = Cache::remember("psgc_mun_{$code}", self::TTL, function () use ($code) {
            $response = Http::withOptions(['verify' => false])
                ->timeout(15)
                ->get(self::BASE . "/provinces/{$code}/cities-municipalities/");

            if (! $response->successful()) {
                return [];
            }

            return collect($response->json())
                ->sortBy('name')
                ->map(fn($m) => ['code' => $m['code'], 'name' => $m['name']])
                ->values()
                ->toArray();
        });

        return response()->json($data);
    }

    public function barangays(string $code)
    {
        $data = Cache::remember("psgc_brgy_{$code}", self::TTL, function () use ($code) {
            $response = Http::withOptions(['verify' => false])
                ->timeout(15)
                ->get(self::BASE . "/cities-municipalities/{$code}/barangays/");

            if (! $response->successful()) {
                return [];
            }

            return collect($response->json())
                ->sortBy('name')
                ->map(fn($b) => ['code' => $b['code'], 'name' => $b['name']])
                ->values()
                ->toArray();
        });

        return response()->json($data);
    }

    /** Fallback: hardcoded list of all Philippine provinces */
    private function fallbackProvinces(): array
    {
        return [
            ['code'=>'PH-ABR','name'=>'Abra'],
            ['code'=>'PH-AGN','name'=>'Agusan del Norte'],
            ['code'=>'PH-AGS','name'=>'Agusan del Sur'],
            ['code'=>'PH-AKL','name'=>'Aklan'],
            ['code'=>'PH-ALB','name'=>'Albay'],
            ['code'=>'PH-ANT','name'=>'Antique'],
            ['code'=>'PH-APY','name'=>'Apayao'],
            ['code'=>'PH-AUR','name'=>'Aurora'],
            ['code'=>'PH-BAS','name'=>'Basilan'],
            ['code'=>'PH-BAN','name'=>'Bataan'],
            ['code'=>'PH-BTN','name'=>'Batanes'],
            ['code'=>'PH-BTG','name'=>'Batangas'],
            ['code'=>'PH-BEN','name'=>'Benguet'],
            ['code'=>'PH-BIL','name'=>'Biliran'],
            ['code'=>'PH-BOH','name'=>'Bohol'],
            ['code'=>'PH-BUK','name'=>'Bukidnon'],
            ['code'=>'PH-BUL','name'=>'Bulacan'],
            ['code'=>'PH-CAG','name'=>'Cagayan'],
            ['code'=>'PH-CAN','name'=>'Camarines Norte'],
            ['code'=>'PH-CAS','name'=>'Camarines Sur'],
            ['code'=>'PH-CAM','name'=>'Camiguin'],
            ['code'=>'PH-CAP','name'=>'Capiz'],
            ['code'=>'PH-CAT','name'=>'Catanduanes'],
            ['code'=>'PH-CAV','name'=>'Cavite'],
            ['code'=>'PH-CEB','name'=>'Cebu'],
            ['code'=>'PH-COM','name'=>'Compostela Valley (Davao de Oro)'],
            ['code'=>'PH-NCO','name'=>'Cotabato (North Cotabato)'],
            ['code'=>'PH-DAV','name'=>'Davao del Norte'],
            ['code'=>'PH-DAS','name'=>'Davao del Sur'],
            ['code'=>'PH-DAO','name'=>'Davao Occidental'],
            ['code'=>'PH-DAC','name'=>'Davao de Oro'],
            ['code'=>'PH-DIN','name'=>'Dinagat Islands'],
            ['code'=>'PH-EAS','name'=>'Eastern Samar'],
            ['code'=>'PH-GUI','name'=>'Guimaras'],
            ['code'=>'PH-IFU','name'=>'Ifugao'],
            ['code'=>'PH-ILN','name'=>'Ilocos Norte'],
            ['code'=>'PH-ILS','name'=>'Ilocos Sur'],
            ['code'=>'PH-ILI','name'=>'Iloilo'],
            ['code'=>'PH-ISA','name'=>'Isabela'],
            ['code'=>'PH-KAL','name'=>'Kalinga'],
            ['code'=>'PH-LAG','name'=>'Laguna'],
            ['code'=>'PH-LAN','name'=>'Lanao del Norte'],
            ['code'=>'PH-LAS','name'=>'Lanao del Sur'],
            ['code'=>'PH-LEY','name'=>'Leyte'],
            ['code'=>'PH-MAG','name'=>'Maguindanao'],
            ['code'=>'PH-MAR','name'=>'Marinduque'],
            ['code'=>'PH-MAS','name'=>'Masbate'],
            ['code'=>'PH-MDN','name'=>'Misamis Occidental'],
            ['code'=>'PH-MDS','name'=>'Misamis Oriental'],
            ['code'=>'PH-MOU','name'=>'Mountain Province'],
            ['code'=>'PH-NEC','name'=>'Negros Occidental'],
            ['code'=>'PH-NER','name'=>'Negros Oriental'],
            ['code'=>'PH-NSA','name'=>'Northern Samar'],
            ['code'=>'PH-NUE','name'=>'Nueva Ecija'],
            ['code'=>'PH-NUV','name'=>'Nueva Vizcaya'],
            ['code'=>'PH-MDC','name'=>'Occidental Mindoro'],
            ['code'=>'PH-MOR','name'=>'Oriental Mindoro'],
            ['code'=>'PH-PLW','name'=>'Palawan'],
            ['code'=>'PH-PAM','name'=>'Pampanga'],
            ['code'=>'PH-PAN','name'=>'Pangasinan'],
            ['code'=>'PH-QUE','name'=>'Quezon'],
            ['code'=>'PH-QUI','name'=>'Quirino'],
            ['code'=>'PH-RIZ','name'=>'Rizal'],
            ['code'=>'PH-ROM','name'=>'Romblon'],
            ['code'=>'PH-SAR','name'=>'Samar (Western Samar)'],
            ['code'=>'PH-SAR','name'=>'Sarangani'],
            ['code'=>'PH-SIG','name'=>'Siquijor'],
            ['code'=>'PH-SOR','name'=>'Sorsogon'],
            ['code'=>'PH-SCO','name'=>'South Cotabato'],
            ['code'=>'PH-SLE','name'=>'Southern Leyte'],
            ['code'=>'PH-SUK','name'=>'Sultan Kudarat'],
            ['code'=>'PH-SLU','name'=>'Sulu'],
            ['code'=>'PH-SUN','name'=>'Surigao del Norte'],
            ['code'=>'PH-SUS','name'=>'Surigao del Sur'],
            ['code'=>'PH-TAR','name'=>'Tarlac'],
            ['code'=>'PH-TAW','name'=>'Tawi-Tawi'],
            ['code'=>'PH-ZMB','name'=>'Zambales'],
            ['code'=>'PH-ZAN','name'=>'Zamboanga del Norte'],
            ['code'=>'PH-ZAS','name'=>'Zamboanga del Sur'],
            ['code'=>'PH-ZSI','name'=>'Zamboanga Sibugay'],
        ];
    }
}
