import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../widgets/glass/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _notifs = {'newsletter':true,'media':true,'alerts':false,'watchtime':false};
  final _integrations = [
    ('Jellyfin','🎬',true),('Jellyseerr','🎥',true),('n8n','⚡',true),
    ('Ollama','🤖',true),('TMDB','🎭',true),('Uptime Kuma','✅',true),
  ];

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom:12),
    child:GlassCard(weight:GlassWeight.mid,borderRadius:24,padding:const EdgeInsets.all(18),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title.toUpperCase(),style:const TextStyle(fontSize:10,letterSpacing:1.1,color:Colors.white35,fontWeight:FontWeight.w600)),
        const SizedBox(height:14),
        child,
      ])));

  Widget _row(String label, String sub, Widget right, {bool last=false}) => Column(children:[
    Padding(padding:const EdgeInsets.symmetric(vertical:12),
      child:Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(label,style:const TextStyle(fontSize:14)),
          if(sub.isNotEmpty) Text(sub,style:const TextStyle(fontSize:11,color:Colors.white35)),
        ])),
        right,
      ])),
    if(!last) Divider(color:Colors.white.withOpacity(0.07),height:1),
  ]);

  Widget _toggle(bool on, VoidCallback onToggle) => GestureDetector(
    onTap:onToggle,
    child:AnimatedContainer(
      duration:const Duration(milliseconds:300),
      width:46,height:26,
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(13),
        gradient:on?LinearGradient(colors:[AppColors.violet,AppColors.cyan]):null,
        color:on?null:Colors.white.withOpacity(0.1),
        border:Border.all(color:on?AppColors.violet.withOpacity(0.4):Colors.white.withOpacity(0.1)),
        boxShadow:on?[BoxShadow(color:AppColors.violet.withOpacity(0.5),blurRadius:16)]:null),
      child:Stack(children:[
        AnimatedPositioned(
          duration:const Duration(milliseconds:300),
          top:3,left:on?22:3,
          child:Container(width:18,height:18,decoration:BoxDecoration(shape:BoxShape.circle,color:Colors.white,boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.3),blurRadius:6)]))),
      ])));

  @override
  Widget build(BuildContext context) {
    return SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(14,16,14,100),children:[
      const Text('Einstellungen',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800,letterSpacing:-1)),
      const SizedBox(height:16),
      // Profile
      GlassCard(weight:GlassWeight.thick,rimColor:AppColors.violet.withOpacity(0.3),
        padding:const EdgeInsets.all(18),
        child:Row(children:[
          Container(width:56,height:56,decoration:BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(colors:[AppColors.violet,AppColors.cyan]),
            boxShadow:[BoxShadow(color:AppColors.violet.withOpacity(0.5),blurRadius:24)]),
            child:const Center(child:Text('C',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800)))),
          const SizedBox(width:14),
          Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Constantin Trapp',style:TextStyle(fontWeight:FontWeight.w700,fontSize:17)),
            const Text('c.trapp@t-acc.com',style:TextStyle(fontSize:12,color:Colors.white40)),
            const SizedBox(height:7),
            GlassCard(borderRadius:8,weight:GlassWeight.thin,padding:const EdgeInsets.symmetric(horizontal:10,vertical:3),
              child:Text('Admin',style:TextStyle(fontSize:10,color:AppColors.violet.withOpacity(0.9),letterSpacing:0.8,fontWeight:FontWeight.w700))),
          ]),
        ])),
      const SizedBox(height:12),
      _section('Server',Column(children:[
        _row('Server URL','hub.t-acc.com',Row(children:[StatusDot(online:true),const SizedBox(width:6),const Text('Online',style:TextStyle(fontSize:11,color:Colors.white38))])),
        _row('TMDB API','Für Filminfos & Poster',GlassCard(borderRadius:10,weight:GlassWeight.thin,padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:const Text('Aktiv',style:TextStyle(fontSize:11,color:Colors.white50))),last:true),
      ])),
      _section('Benachrichtigungen',Column(children:[
        _row('Newsletter','Neue Ausgaben via n8n',_toggle(_notifs['newsletter']!,()=>setState(()=>_notifs['newsletter']=!_notifs['newsletter']!))),
        _row('Neue Medien','Jellyfin Neuheiten',_toggle(_notifs['media']!,()=>setState(()=>_notifs['media']=!_notifs['media']!))),
        _row('Service Alerts','Uptime Kuma → Push',_toggle(_notifs['alerts']!,()=>setState(()=>_notifs['alerts']=!_notifs['alerts']!))),
        _row('Watchtime Report','Jeden Freitag 17:00',_toggle(_notifs['watchtime']!,()=>setState(()=>_notifs['watchtime']=!_notifs['watchtime']!)),last:true),
      ])),
      _section('Integrationen',Column(children:_integrations.asMap().entries.map((e){
        final i=e.key; final s=e.value;
        return _row(s.$1,'',Row(children:[StatusDot(online:s.$3),const SizedBox(width:6),Text(s.$3?'Verbunden':'Offline',style:const TextStyle(fontSize:11,color:Colors.white38))]),last:i==_integrations.length-1);
      }).toList())),
      _section('App',Column(children:[
        _row('Version','Family Hub v2.0',const Text('Aktuell',style:TextStyle(fontSize:12,color:Colors.white30))),
        _row('Flutter Build','iOS & Android',GlassCard(borderRadius:10,weight:GlassWeight.thin,padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:const Text('Build ›',style:TextStyle(fontSize:11,color:Colors.white50))),last:true),
      ])),
    ]));
  }
}
