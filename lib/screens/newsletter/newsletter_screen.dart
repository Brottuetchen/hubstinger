// newsletter_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/colors.dart';
import '../../widgets/glass/glass_card.dart';

class NewsletterScreen extends StatefulWidget {
  const NewsletterScreen({super.key});
  @override State<NewsletterScreen> createState() => _NewsletterScreenState();
}

class _NewsletterScreenState extends State<NewsletterScreen> {
  int? _open;

  static const _issues = [
    ('April Picks 🎬', '25. Apr 2026', 17, 8, AppColors.violet,
      [('Dune: Part Two',8.4,'🏜️'),('The Brutalist',8.1,'🏛️'),('Adolescence',8.9,'👦'),('A Complete Unknown',7.8,'🎸'),('Black Bag',7.2,'🕵️')]),
    ('April Serien 📺', '18. Apr 2026', 16, 6, AppColors.blue,
      [('Severance S02',9.0,'🏢'),('The Last of Us S02',8.8,'🍄'),('White Lotus S03',8.5,'🌺')]),
    ('März Highlights', '30. Mär 2026', 13, 10, AppColors.green,
      [('Conclave',7.9,'⛪'),('Emilia Pérez',7.4,'💃')]),
  ];

  @override
  Widget build(BuildContext context) {
    if (_open != null) return _buildDetail(_open!);
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(14,16,14,100), children: [
      const Text('Newsletter', style: TextStyle(fontSize:30,fontWeight:FontWeight.w800,letterSpacing:-1)),
      const SizedBox(height:4),
      const Text('Wöchentlich · automatisch via n8n', style: TextStyle(fontSize:13,color:Colors.white38)),
      const SizedBox(height:16),
      // Next issue card
      GlassCard(weight:GlassWeight.thick,tint:AppColors.violet.withOpacity(0.18),rimColor:AppColors.violet.withOpacity(0.5),
        padding:const EdgeInsets.all(20),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('NÄCHSTE AUSGABE',style:TextStyle(fontSize:10,letterSpacing:1.1,color:AppColors.violet.withOpacity(0.85),fontWeight:FontWeight.w700)),
          const SizedBox(height:10),
          const Text('Mai 2026 Picks',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,letterSpacing:-0.5)),
          const SizedBox(height:6),
          const Text('Automatisch in 6 Tagen · KW 18',style:TextStyle(fontSize:13,color:Colors.white40)),
          const SizedBox(height:14),
          GlassProgressBar(value:0.83,color:AppColors.violet),
          const SizedBox(height:6),
          const Text('83% des Monats vergangen',style:TextStyle(fontSize:11,color:Colors.white25)),
        ])),
      const SizedBox(height:20),
      const Text('ARCHIV',style:TextStyle(fontSize:10,letterSpacing:1.1,color:Colors.white30,fontWeight:FontWeight.w600)),
      const SizedBox(height:10),
      ..._issues.asMap().entries.map((entry) {
        final i = entry.key; final n = entry.value;
        return Padding(
          padding:const EdgeInsets.only(bottom:10),
          child:GlassCard(
            borderRadius:22,weight:GlassWeight.mid,rimColor:n.$5.withOpacity(0.3),
            tint:n.$5.withOpacity(0.08),onTap:()=>setState(()=>_open=i),
            padding:const EdgeInsets.all(14),
            child:Row(children:[
              Container(width:44,height:44,decoration:BoxDecoration(borderRadius:BorderRadius.circular(13),color:n.$5.withOpacity(0.15),border:Border.all(color:n.$5.withOpacity(0.3))),
                child:const Center(child:Text('📬',style:TextStyle(fontSize:22)))),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(n.$1,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600)),
                Text('${n.$2} · ${n.$4} Empfehlungen',style:const TextStyle(fontSize:11,color:Colors.white35)),
              ])),
              const Text('›',style:TextStyle(fontSize:18,color:Colors.white22)),
            ]),
          ).animate().fadeIn(delay:Duration(milliseconds:i*80),duration:300.ms),
        );
      }),
    ]));
  }

  Widget _buildDetail(int index) {
    final n = _issues[index];
    return SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(14,16,14,12),
        child:Row(children:[
          GlassCard(borderRadius:14,weight:GlassWeight.mid,onTap:()=>setState(()=>_open=null),
            padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),
            child:const Text('‹ Zurück',style:TextStyle(fontSize:13,color:Colors.white60))),
          const SizedBox(width:14),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(n.$1,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800,letterSpacing:-0.5)),
            Text('KW ${n.$3} · ${n.$4} Empfehlungen',style:const TextStyle(fontSize:11,color:Colors.white38)),
          ])),
        ])),
      Expanded(child:ListView.builder(padding:const EdgeInsets.fromLTRB(14,0,14,100),
        itemCount:n.$6.length,
        itemBuilder:(ctx,i){
          final f=n.$6[i];
          return Padding(padding:const EdgeInsets.only(bottom:12),
            child:GlassCard(weight:GlassWeight.mid,rimColor:n.$5.withOpacity(0.3),tint:n.$5.withOpacity(0.08),
              padding:const EdgeInsets.all(16),
              child:Row(children:[
                Container(width:56,height:80,decoration:BoxDecoration(borderRadius:BorderRadius.circular(13),color:n.$5.withOpacity(0.15),border:Border.all(color:n.$5.withOpacity(0.3))),
                  child:Center(child:Text(f.$3,style:const TextStyle(fontSize:30)))),
                const SizedBox(width:14),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(f.$1,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700,letterSpacing:-0.3)),
                  const SizedBox(height:6),
                  Row(children:[
                    Text('★',style:TextStyle(color:AppColors.amber,fontSize:14)),
                    Text(f.$2.toStringAsFixed(1),style:TextStyle(color:AppColors.amber,fontWeight:FontWeight.w700,fontSize:14)),
                  ]),
                  const SizedBox(height:10),
                  GlassCard(borderRadius:12,weight:GlassWeight.thin,padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),
                    child:const Text('📋 Anfragen',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
                ])),
              ])).animate().fadeIn(delay:Duration(milliseconds:i*60),duration:300.ms));
        })),
    ]));
  }
}
