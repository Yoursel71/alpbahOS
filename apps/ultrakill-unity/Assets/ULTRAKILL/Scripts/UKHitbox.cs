// Vurulabilir bölge: düşman gövdesi (CharacterController ile aynı nesne) ya da kafa (tetik küre).
using UnityEngine;

namespace UK
{
    public class UKHitbox : MonoBehaviour
    {
        public UKEnemy owner;
        public bool head;

        // Gövde kapsülü kafa küresini sardığı için ışın önce gövdeye çarpar. Aynı düşmanın kafası
        // hemen arkadaysa (within metre) isabeti kafaya say. hits mesafeye göre sıralı olmalı.
        public static UKHitbox PreferHead(RaycastHit[] hits, int i, UKHitbox body, float within, out RaycastHit hit)
        {
            hit = hits[i];
            if (body.head) return body;
            float limit = hits[i].distance + within;
            for (int k = i + 1; k < hits.Length && hits[k].distance <= limit; k++)
            {
                var hb = hits[k].collider.GetComponent<UKHitbox>();
                if (hb != null && hb.head && hb.owner == body.owner) { hit = hits[k]; return hb; }
            }
            return body;
        }
    }
}
