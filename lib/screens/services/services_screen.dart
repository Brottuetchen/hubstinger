// services_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/colors.dart';
import '../../widgets/glass/glass_card.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _filter = 'Alle';

  static const _services = [
    ('Jellyfin','🎬',AppColors.cyan,true,'Media'),
    ('Immich','📷',Color(0xFFa855f7),true,'Media'),
    ('Navidrome','🎵',AppColors.green,true,'Media'),
    ('Audiobookshelf','🎧',AppColors.amber,true,'Media'),
    ('Nextcloud','☁️',AppColors.blue,true,'Storage'),
    ('Vaultwarden','🔐',Color(0xFF6366f1),true,'Tools'),
    ('n8n','⚡',AppColors.orange,true,'Tools'),
    ('Grafana','📊',AppColors.orange,true,'Monitor'),
    ('Uptime Kuma','✅',AppColors.green,true,'Monitor'),
    ('Proxmox','🖥️',AppColors.orange,true,'Infra'),
    ('Paperless','📄',Color(0xFF64748b),false,'Tools'),
    ('Gitea','🐙',AppColors.green,true,'Dev'),
    ('Jellyseerr','🎥',Color(0xFFa855f7),true,'Media'),
    ('slskd','🎼',AppColors.rose,true,'Media'),
    ('Portainer','🐳',AppColors.blue,true,'Infra'),
    ('NPM','🔀',AppColors.green,true,'Infra'),
  ];

  @override
  Widget build(BuildContext context) {
    final cats = ['Alle',...{..._services.map((s)=>s.$5)}];
    final filtered = _filter=='Alle' ? _services : _services.where((s)=>s.$5==_filter).toList();
    final online = _services.where((s)=>s.$4).length;

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18,16,18,12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Services', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
            const SizedBox(height:4),
            Row(children: [
              StatusDot(online: true),
              const SizedBox(width:8),
              Text('$online von ${_services.length} online', style: const TextStyle(fontSize:13,color:Colors.white38)),
            ]),
            const SizedBox(height:14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: cats.map((c)=>Padding(
                padding: const EdgeInsets.only(right:8),
                child: GlassPill(label:c, active:_filter==c, onTap:()=>setState(()=>_filter=c), activeColor:AppColors.violet),
              )).toList()),
            ),
          ]),
        ),
        Expanded(child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal:14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:3, childAspectRatio:0.85, crossAxisSpacing:11, mainAxisSpacing:11),
          itemCount: filtered.length,
          itemBuilder: (ctx,i) {
            final s = filtered[i];
            return GlassCard(
              borderRadius:22, weight:GlassWeight.mid,
              rimColor: s.$3.withOpacity(s.$4?0.4:0.1),
              child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[
                Container(width:50,height:50,
                  decoration:BoxDecoration(borderRadius:BorderRadius.circular(15),
                    color:s.$3.withOpacity(0.15), border:Border.all(color:s.$3.withOpacity(s.$4?0.4:0.15))),
                  child:Center(child:Text(s.$2,style:const TextStyle(fontSize:24)))),
                const SizedBox(height:8),
                Text(s.$1,style:TextStyle(fontSize:10,fontWeight:FontWeight.w500,color:s.$4?Colors.white75:Colors.white30),textAlign:TextAlign.center),
                const SizedBox(height:6),
                StatusDot(online:s.$4,size:6),
              ]),
            ).animate().fadeIn(delay:Duration(milliseconds:i*30),duration:300.ms);
          },
        )),
      ]),
    );
  }
}
